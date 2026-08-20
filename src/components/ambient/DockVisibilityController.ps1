param()

$ErrorActionPreference = "Stop"

$controllerRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateRoot = $env:LOCALAPPDATA + "\ObsidianDockVisibility"
$statePath = $stateRoot + "\mode.txt"
$logRoot = $controllerRoot + "\logs"
$logPath = $logRoot + "\dock-visibility-controller.log"

if (!(Test-Path -LiteralPath $stateRoot)) {
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
}
if (!(Test-Path -LiteralPath $logRoot)) {
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
}
if (!(Test-Path -LiteralPath $statePath)) {
    Set-Content -LiteralPath $statePath -Value "fixed" -NoNewline -Encoding ASCII
}

$createdNew = $false
$mutex = New-Object Threading.Mutex($true, "Local\ObsidianDockVisibility.Controller", [ref]$createdNew)
if (!$createdNew) {
    exit 0
}

$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace ObsidianDockVisibility
{
    public sealed class Controller : ApplicationContext
    {
        private const int WH_MOUSE_LL = 14;
        private const int WM_LBUTTONDOWN = 0x0201;
        private const int SW_HIDE = 0;
        private const int SW_SHOWNOACTIVATE = 4;
        private const uint GA_ROOT = 2;
        private const uint LVM_HITTEST = 0x1012;

        private readonly string statePath;
        private readonly string logPath;
        private readonly NativeMethods.LowLevelMouseProc mouseProcedure;
        private readonly Timer stabilityTimer;
        private readonly Timer singleClickTimer;
        private IntPtr mouseHook = IntPtr.Zero;
        private string mode;
        private bool waitingForSecondClick;
        private int pendingClickTick;
        private Point pendingClickPoint;
        private int lastCorrectionTick;
        private bool dockWasFound;

        public Controller(string stateFile, string logFile)
        {
            statePath = stateFile;
            logPath = logFile;
            mode = ReadMode();

            mouseProcedure = MouseHookCallback;
            mouseHook = NativeMethods.SetWindowsHookEx(
                WH_MOUSE_LL,
                mouseProcedure,
                NativeMethods.GetModuleHandle(null),
                0);

            stabilityTimer = new Timer();
            stabilityTimer.Interval = 350;
            stabilityTimer.Tick += StabilityTimerTick;
            stabilityTimer.Start();

            singleClickTimer = new Timer();
            singleClickTimer.Interval = Math.Min(Math.Max((int)NativeMethods.GetDoubleClickTime() + 30, 180), 650);
            singleClickTimer.Tick += SingleClickTimerTick;

            if (mouseHook == IntPtr.Zero)
            {
                Log("Mouse hook was unavailable. The saved mode guard remains active.");
            }
            else
            {
                Log("Blank desktop click controller started in " + mode + " mode.");
            }

            ApplyMode(true);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                if (mouseHook != IntPtr.Zero)
                {
                    NativeMethods.UnhookWindowsHookEx(mouseHook);
                    mouseHook = IntPtr.Zero;
                }
                stabilityTimer.Stop();
                stabilityTimer.Dispose();
                singleClickTimer.Stop();
                singleClickTimer.Dispose();
            }

            base.Dispose(disposing);
        }

        private void StabilityTimerTick(object sender, EventArgs eventArgs)
        {
            string savedMode = ReadMode();
            if (!String.Equals(savedMode, mode, StringComparison.OrdinalIgnoreCase))
            {
                mode = savedMode;
                Log("Saved mode changed to " + mode + ".");
            }

            ApplyMode(false);
        }

        private void SingleClickTimerTick(object sender, EventArgs eventArgs)
        {
            singleClickTimer.Stop();
            if (!waitingForSecondClick)
            {
                return;
            }

            waitingForSecondClick = false;
            SetMode("collapsed", "Blank desktop single click");
        }

        private IntPtr MouseHookCallback(int code, IntPtr wParam, IntPtr lParam)
        {
            if (code >= 0 && wParam.ToInt32() == WM_LBUTTONDOWN)
            {
                NativeMethods.MSLLHOOKSTRUCT mouseData = (NativeMethods.MSLLHOOKSTRUCT)Marshal.PtrToStructure(
                    lParam,
                    typeof(NativeMethods.MSLLHOOKSTRUCT));

                Point screenPoint = new Point(mouseData.pt.x, mouseData.pt.y);
                if (IsBlankDesktopArea(screenPoint) || IsBlankApplicationSurface(screenPoint))
                {
                    ProcessBlankDesktopClick(screenPoint);
                }
            }

            return NativeMethods.CallNextHookEx(mouseHook, code, wParam, lParam);
        }

        private void ProcessBlankDesktopClick(Point screenPoint)
        {
            int now = Environment.TickCount;
            int elapsed = unchecked(now - pendingClickTick);
            int allowedDelay = (int)NativeMethods.GetDoubleClickTime();
            int deltaX = screenPoint.X - pendingClickPoint.X;
            int deltaY = screenPoint.Y - pendingClickPoint.Y;
            bool closeEnough = (deltaX * deltaX) + (deltaY * deltaY) <= 144;

            if (waitingForSecondClick && elapsed >= 0 && elapsed <= allowedDelay && closeEnough)
            {
                waitingForSecondClick = false;
                singleClickTimer.Stop();
                SetMode("fixed", "Blank desktop double click");
                return;
            }

            pendingClickTick = now;
            pendingClickPoint = screenPoint;
            waitingForSecondClick = true;
            singleClickTimer.Stop();
            singleClickTimer.Start();
        }

        private void SetMode(string requestedMode, string reason)
        {
            string normalizedMode = String.Equals(requestedMode, "collapsed", StringComparison.OrdinalIgnoreCase)
                ? "collapsed"
                : "fixed";

            mode = normalizedMode;
            try
            {
                File.WriteAllText(statePath, mode, Encoding.ASCII);
            }
            catch (Exception exception)
            {
                Log("Could not save dock mode: " + exception.Message);
            }

            Log(reason + " -> " + mode + ".");
            ApplyMode(true);
        }

        private string ReadMode()
        {
            try
            {
                string value = File.ReadAllText(statePath).Trim();
                if (String.Equals(value, "collapsed", StringComparison.OrdinalIgnoreCase))
                {
                    return "collapsed";
                }
            }
            catch
            {
            }

            return "fixed";
        }

        private void ApplyMode(bool force)
        {
            IntPtr dockPanel = NativeMethods.FindWindow("MyDockAPP", null);
            if (dockPanel == IntPtr.Zero)
            {
                if (dockWasFound)
                {
                    Log("MyDockFinder panel is not available. Waiting for it to return.");
                }
                dockWasFound = false;
                return;
            }

            if (!dockWasFound)
            {
                dockWasFound = true;
                Log("MyDockFinder panel detected.");
            }

            bool visible = NativeMethods.IsWindowVisible(dockPanel);
            NativeMethods.RECT rectangle;
            NativeMethods.GetWindowRect(dockPanel, out rectangle);
            int panelHeight = rectangle.Bottom - rectangle.Top;
            bool shouldCorrect = mode == "collapsed"
                ? visible && panelHeight > 2
                : !visible || panelHeight < 12;

            if (!shouldCorrect)
            {
                return;
            }

            int now = Environment.TickCount;
            int elapsed = unchecked(now - lastCorrectionTick);
            if (!force && elapsed >= 0 && elapsed < 650)
            {
                return;
            }

            lastCorrectionTick = now;
            if (mode == "collapsed")
            {
                NativeMethods.ShowWindowAsync(dockPanel, SW_HIDE);
            }
            else
            {
                NativeMethods.ShowWindowAsync(dockPanel, SW_SHOWNOACTIVATE);
            }
        }

        private bool IsBlankDesktopArea(Point screenPoint)
        {
            NativeMethods.POINT nativePoint = new NativeMethods.POINT();
            nativePoint.x = screenPoint.X;
            nativePoint.y = screenPoint.Y;
            IntPtr target = NativeMethods.WindowFromPoint(nativePoint);
            if (target == IntPtr.Zero || !IsDesktopWindowOrChild(target))
            {
                return false;
            }

            string targetClass = NativeMethods.GetClassName(target);
            if (String.Equals(targetClass, "SysListView32", StringComparison.OrdinalIgnoreCase))
            {
                return !DesktopListViewHasItemAt(target, screenPoint);
            }

            return true;
        }

        private bool IsBlankApplicationSurface(Point screenPoint)
        {
            NativeMethods.POINT nativePoint = new NativeMethods.POINT();
            nativePoint.x = screenPoint.X;
            nativePoint.y = screenPoint.Y;
            IntPtr target = NativeMethods.WindowFromPoint(nativePoint);
            if (target == IntPtr.Zero || IsDesktopWindowOrChild(target))
            {
                return false;
            }

            IntPtr root = NativeMethods.GetAncestor(target, GA_ROOT);
            if (root == IntPtr.Zero || IsDockWindow(target) || IsDockWindow(root))
            {
                return false;
            }

            if (target == root)
            {
                return true;
            }

            if (IsProtectedApplication(root))
            {
                return false;
            }

            string targetClass = NativeMethods.GetClassName(target);
            return String.Equals(targetClass, "Static", StringComparison.OrdinalIgnoreCase)
                && String.IsNullOrWhiteSpace(NativeMethods.GetWindowText(target));
        }

        private static bool IsDockWindow(IntPtr window)
        {
            string className = NativeMethods.GetClassName(window);
            return className.StartsWith("MyDock", StringComparison.OrdinalIgnoreCase)
                || className.StartsWith("MyFinder", StringComparison.OrdinalIgnoreCase)
                || String.Equals(className, "dockhook32", StringComparison.OrdinalIgnoreCase);
        }

        private static bool IsProtectedApplication(IntPtr root)
        {
            uint processId = 0;
            NativeMethods.GetWindowThreadProcessId(root, out processId);
            if (processId == 0)
            {
                return false;
            }

            try
            {
                string processName = Process.GetProcessById((int)processId).ProcessName;
                return String.Equals(processName, "chrome", StringComparison.OrdinalIgnoreCase)
                    || String.Equals(processName, "msedge", StringComparison.OrdinalIgnoreCase)
                    || String.Equals(processName, "msedgewebview2", StringComparison.OrdinalIgnoreCase)
                    || String.Equals(processName, "code", StringComparison.OrdinalIgnoreCase)
                    || String.Equals(processName, "chatgpt", StringComparison.OrdinalIgnoreCase)
                    || String.Equals(processName, "codex", StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                return false;
            }
        }

        private bool IsDesktopWindowOrChild(IntPtr window)
        {
            IntPtr root = NativeMethods.GetAncestor(window, GA_ROOT);
            if (IsDesktopClass(NativeMethods.GetClassName(root)))
            {
                return true;
            }

            IntPtr current = window;
            for (int index = 0; index < 12 && current != IntPtr.Zero; index++)
            {
                if (IsDesktopClass(NativeMethods.GetClassName(current)))
                {
                    return true;
                }
                current = NativeMethods.GetParent(current);
            }

            return false;
        }

        private static bool IsDesktopClass(string className)
        {
            return String.Equals(className, "WorkerW", StringComparison.OrdinalIgnoreCase)
                || String.Equals(className, "Progman", StringComparison.OrdinalIgnoreCase)
                || String.Equals(className, "SHELLDLL_DefView", StringComparison.OrdinalIgnoreCase);
        }

        private bool DesktopListViewHasItemAt(IntPtr listView, Point screenPoint)
        {
            NativeMethods.POINT clientPoint = new NativeMethods.POINT();
            clientPoint.x = screenPoint.X;
            clientPoint.y = screenPoint.Y;
            if (!NativeMethods.ScreenToClient(listView, ref clientPoint))
            {
                return false;
            }

            NativeMethods.LVHITTESTINFO hitTest = new NativeMethods.LVHITTESTINFO();
            hitTest.pt = clientPoint;
            IntPtr result = NativeMethods.SendMessage(listView, LVM_HITTEST, IntPtr.Zero, ref hitTest);
            return result.ToInt64() >= 0;
        }

        private void Log(string message)
        {
            try
            {
                string directory = Path.GetDirectoryName(logPath);
                if (!String.IsNullOrEmpty(directory))
                {
                    Directory.CreateDirectory(directory);
                }
                File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  " + message + Environment.NewLine, Encoding.UTF8);
            }
            catch
            {
            }
        }
    }

    internal static class NativeMethods
    {
        public delegate IntPtr LowLevelMouseProc(int code, IntPtr wParam, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int x;
            public int y;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct MSLLHOOKSTRUCT
        {
            public POINT pt;
            public uint mouseData;
            public uint flags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct LVHITTESTINFO
        {
            public POINT pt;
            public uint flags;
            public int iItem;
            public int iSubItem;
            public int iGroup;
        }

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr SetWindowsHookEx(int hookId, LowLevelMouseProc callback, IntPtr module, uint threadId);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool UnhookWindowsHookEx(IntPtr hook);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr GetModuleHandle(string moduleName);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr FindWindow(string className, string windowName);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWindowVisible(IntPtr window);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindowAsync(IntPtr window, int command);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

        [DllImport("user32.dll")]
        public static extern IntPtr WindowFromPoint(POINT point);

        [DllImport("user32.dll")]
        public static extern IntPtr GetAncestor(IntPtr window, uint flags);

        [DllImport("user32.dll")]
        public static extern IntPtr GetParent(IntPtr window);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int GetClassName(IntPtr window, StringBuilder className, int count);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int GetWindowText(IntPtr window, StringBuilder text, int count);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ScreenToClient(IntPtr window, ref POINT point);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessage(IntPtr window, uint message, IntPtr wParam, ref LVHITTESTINFO lParam);

        [DllImport("user32.dll")]
        public static extern uint GetDoubleClickTime();

        public static string GetClassName(IntPtr window)
        {
            if (window == IntPtr.Zero)
            {
                return String.Empty;
            }

            StringBuilder value = new StringBuilder(256);
            GetClassName(window, value, value.Capacity);
            return value.ToString();
        }

        public static string GetWindowText(IntPtr window)
        {
            if (window == IntPtr.Zero)
            {
                return String.Empty;
            }

            StringBuilder value = new StringBuilder(512);
            GetWindowText(window, value, value.Capacity);
            return value.ToString();
        }
    }
}
'@

if (-not ("ObsidianDockVisibility.Controller" -as [type])) {
    Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Windows.Forms", "System.Drawing"
}

try {
    $controller = New-Object ObsidianDockVisibility.Controller($statePath, $logPath)
    [System.Windows.Forms.Application]::Run($controller)
} finally {
    if ($null -ne $controller) {
        $controller.Dispose()
    }
    if ($createdNew) {
        try { $mutex.ReleaseMutex() } catch { }
    }
    $mutex.Dispose()
}
