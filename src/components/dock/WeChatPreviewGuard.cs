using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class WeChatPreviewGuard
{
    private const uint WmClose = 0x0010;
    private const int SwRestore = 9;
    private const uint EventSystemForeground = 0x0003;
    private const uint EventObjectShow = 0x8002;
    private const uint WineventOutOfContext = 0x0000;
    private const uint WineventSkipOwnProcess = 0x0002;
    private const long MainWindowMinimumArea = 250000;
    private const double LoginWindowMaximumRatio = 0.65;
    private static string logPath;
    private static int scanRunning;
    private static WinEventDelegate winEventCallback;

    private sealed class WindowCandidate
    {
        public IntPtr Handle;
        public int ProcessId;
        public long Area;
    }

    [STAThread]
    private static void Main()
    {
        bool created;
        using (var mutex = new Mutex(true, "Local\\ObsidianAIDock.WeChatPreviewGuard.v2", out created))
        {
            if (!created)
            {
                return;
            }

            var logFolder = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "logs");
            Directory.CreateDirectory(logFolder);
            logPath = Path.Combine(logFolder, "wechat-preview-guard.log");
            Log("Guard started.");

            try
            {
                winEventCallback = HandleWinEvent;
                var foregroundHook = SetWinEventHook(
                    EventSystemForeground,
                    EventSystemForeground,
                    IntPtr.Zero,
                    winEventCallback,
                    0,
                    0,
                    WineventOutOfContext | WineventSkipOwnProcess);
                var showHook = SetWinEventHook(
                    EventObjectShow,
                    EventObjectShow,
                    IntPtr.Zero,
                    winEventCallback,
                    0,
                    0,
                    WineventOutOfContext | WineventSkipOwnProcess);

                if (foregroundHook == IntPtr.Zero || showHook == IntPtr.Zero)
                {
                    Log("Unable to install the Windows event hooks.");
                    return;
                }

                QueueScan();
                NativeMessage message;
                while (GetMessage(out message, IntPtr.Zero, 0, 0) > 0)
                {
                    TranslateMessage(ref message);
                    DispatchMessage(ref message);
                }
                UnhookWinEvent(foregroundHook);
                UnhookWinEvent(showHook);
            }
            catch (Exception ex)
            {
                Log("Guard error: " + ex.Message);
            }
        }
    }

    private static void HandleWinEvent(
        IntPtr hook,
        uint eventType,
        IntPtr windowHandle,
        int objectId,
        int childId,
        uint eventThread,
        uint eventTime)
    {
        if (windowHandle == IntPtr.Zero)
        {
            return;
        }

        uint processId;
        GetWindowThreadProcessId(windowHandle, out processId);
        if (processId != 0 && IsWeChatProcess((int)processId) && GetClassName(windowHandle) == "Qt51514QWindowIcon")
        {
            QueueScan();
        }
    }

    private static void QueueScan()
    {
        if (Interlocked.Exchange(ref scanRunning, 1) != 0)
        {
            return;
        }

        ThreadPool.QueueUserWorkItem(delegate
        {
            try
            {
                for (var attempt = 0; attempt < 6; attempt++)
                {
                    Thread.Sleep(250);
                    if (CloseExtraLoginWindow())
                    {
                        break;
                    }
                }
            }
            catch (Exception ex)
            {
                Log("Scan error: " + ex.Message);
            }
            finally
            {
                Interlocked.Exchange(ref scanRunning, 0);
            }
        });
    }

    private static bool CloseExtraLoginWindow()
    {
        var candidates = new List<WindowCandidate>();

        EnumWindows(delegate(IntPtr handle, IntPtr parameter)
        {
            if (!IsWindowVisible(handle))
            {
                return true;
            }

            uint processId;
            GetWindowThreadProcessId(handle, out processId);
            if (processId == 0 || !IsWeChatProcess((int)processId) || GetClassName(handle) != "Qt51514QWindowIcon")
            {
                return true;
            }

            var title = GetWindowTitle(handle);
            if (!string.Equals(title, "微信", StringComparison.Ordinal))
            {
                return true;
            }

            candidates.Add(new WindowCandidate
            {
                Handle = handle,
                ProcessId = (int)processId,
                Area = GetNormalWindowArea(handle)
            });
            return true;
        }, IntPtr.Zero);

        var processWindows = candidates
            .GroupBy(candidate => candidate.ProcessId)
            .Select(group => group.OrderByDescending(candidate => candidate.Area).First())
            .OrderByDescending(candidate => candidate.Area)
            .ToList();

        if (processWindows.Count < 2 || processWindows[0].Area < MainWindowMinimumArea)
        {
            return false;
        }

        var mainWindow = processWindows[0];
        var closedAny = false;
        foreach (var candidate in processWindows.Skip(1))
        {
            if (candidate.Area > mainWindow.Area * LoginWindowMaximumRatio)
            {
                continue;
            }

            PostMessage(candidate.Handle, WmClose, IntPtr.Zero, IntPtr.Zero);
            Log("Closed extra WeChat login window PID " + candidate.ProcessId + ".");
            closedAny = true;
        }

        if (closedAny)
        {
            ShowWindowAsync(mainWindow.Handle, SwRestore);
            SetForegroundWindow(mainWindow.Handle);
        }

        return closedAny;
    }

    private static bool IsWeChatProcess(int processId)
    {
        try
        {
            return string.Equals(Process.GetProcessById(processId).ProcessName, "Weixin", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private static long GetNormalWindowArea(IntPtr handle)
    {
        var placement = new WindowPlacement();
        placement.Length = Marshal.SizeOf(typeof(WindowPlacement));
        if (GetWindowPlacement(handle, ref placement))
        {
            return Math.Max(0, placement.NormalPosition.Right - placement.NormalPosition.Left) *
                   (long)Math.Max(0, placement.NormalPosition.Bottom - placement.NormalPosition.Top);
        }

        Rect rect;
        return GetWindowRect(handle, out rect)
            ? Math.Max(0, rect.Right - rect.Left) * (long)Math.Max(0, rect.Bottom - rect.Top)
            : 0;
    }

    private static string GetWindowTitle(IntPtr handle)
    {
        var length = GetWindowTextLength(handle);
        var builder = new StringBuilder(length + 1);
        GetWindowText(handle, builder, builder.Capacity);
        return builder.ToString();
    }

    private static string GetClassName(IntPtr handle)
    {
        var builder = new StringBuilder(256);
        GetClassName(handle, builder, builder.Capacity);
        return builder.ToString();
    }

    private static void Log(string message)
    {
        try
        {
            File.AppendAllText(logPath, DateTime.Now.ToString("s") + " " + message + Environment.NewLine);
        }
        catch
        {
        }
    }

    private delegate bool EnumWindowsProc(IntPtr handle, IntPtr parameter);
    private delegate void WinEventDelegate(
        IntPtr hook,
        uint eventType,
        IntPtr windowHandle,
        int objectId,
        int childId,
        uint eventThread,
        uint eventTime);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr handle);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr handle, out uint processId);

    [DllImport("user32.dll")]
    private static extern bool GetWindowPlacement(IntPtr handle, ref WindowPlacement placement);

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr handle, out Rect rect);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr handle, StringBuilder builder, int maximumCount);

    [DllImport("user32.dll")]
    private static extern int GetWindowTextLength(IntPtr handle);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(IntPtr handle, StringBuilder builder, int maximumCount);

    [DllImport("user32.dll")]
    private static extern bool PostMessage(IntPtr handle, uint message, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool ShowWindowAsync(IntPtr handle, int command);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr handle);

    [DllImport("user32.dll")]
    private static extern IntPtr SetWinEventHook(
        uint eventMinimum,
        uint eventMaximum,
        IntPtr eventHookModule,
        WinEventDelegate callback,
        uint processId,
        uint threadId,
        uint flags);

    [DllImport("user32.dll")]
    private static extern bool UnhookWinEvent(IntPtr hook);

    [DllImport("user32.dll")]
    private static extern int GetMessage(out NativeMessage message, IntPtr windowHandle, uint minimumFilter, uint maximumFilter);

    [DllImport("user32.dll")]
    private static extern bool TranslateMessage(ref NativeMessage message);

    [DllImport("user32.dll")]
    private static extern IntPtr DispatchMessage(ref NativeMessage message);

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Point
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct WindowPlacement
    {
        public int Length;
        public int Flags;
        public int ShowCommand;
        public Point MinimumPosition;
        public Point MaximumPosition;
        public Rect NormalPosition;
        public Rect Device;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeMessage
    {
        public IntPtr WindowHandle;
        public uint Message;
        public UIntPtr WParam;
        public IntPtr LParam;
        public uint Time;
        public Point CursorPosition;
    }
}
