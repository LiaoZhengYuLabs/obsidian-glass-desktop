using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

internal static class WeChatDockDot
{
    private const int DetectionIntervalMilliseconds = 900;
    private const int ProcessCheckIntervalMilliseconds = 2000;
    private const int DockWindowSearchIntervalMilliseconds = 2000;
    private const int TimerIntervalMilliseconds = 150;
    private const int DotSize = 9;
    private const int DotBottomOffset = 17;
    private static IntPtr dockWindowHandle = IntPtr.Zero;
    private static ulong lastDockWindowSearch;

    [STAThread]
    private static void Main()
    {
        bool created;
        using (var mutex = new Mutex(true, "Local\\ObsidianAIDock.WeChatDockDot.v1", out created))
        {
            if (!created)
            {
                return;
            }

            SetProcessDpiAwarenessContext(new IntPtr(-4));
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new DotContext());
        }
    }

    private sealed class DotContext : ApplicationContext
    {
        private readonly DotForm dot = new DotForm();
        private readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
        private Point iconCenter = Point.Empty;
        private long lastDetection;
        private long lastProcessCheck;
        private bool wechatRunning;

        public DotContext()
        {
            timer.Interval = TimerIntervalMilliseconds;
            timer.Tick += Tick;
            timer.Start();
            Log("Dot helper started.");
        }

        private void Tick(object sender, EventArgs eventArgs)
        {
            var now = (long)GetTickCount64();

            if (now - lastProcessCheck >= ProcessCheckIntervalMilliseconds)
            {
                lastProcessCheck = now;
                wechatRunning = IsWeChatRunning();
            }

            if (!wechatRunning)
            {
                dot.HideDot();
                return;
            }

            Rect dockRect;
            if (!TryGetDockRect(out dockRect))
            {
                dot.HideDot();
                return;
            }

            var screenBottom = Screen.PrimaryScreen.Bounds.Bottom;
            if (dockRect.Top >= screenBottom - 5)
            {
                dot.HideDot();
                return;
            }

            if (now - lastDetection >= DetectionIntervalMilliseconds)
            {
                lastDetection = now;
                iconCenter = DetectWeChatIcon();
            }

            if (iconCenter == Point.Empty)
            {
                dot.HideDot();
                return;
            }

            dot.ShowDot(new Point(iconCenter.X, dockRect.Bottom - DotBottomOffset));
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                timer.Stop();
                timer.Dispose();
                dot.Dispose();
            }
            base.Dispose(disposing);
        }
    }

    private sealed class DotForm : Form
    {
        public DotForm()
        {
            AutoScaleMode = AutoScaleMode.None;
            ClientSize = new Size(DotSize + 2, DotSize + 2);
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            StartPosition = FormStartPosition.Manual;
            BackColor = Color.FromArgb(154, 154, 155);
            TransparencyKey = Color.FromArgb(154, 154, 155);
            DoubleBuffered = true;
        }

        protected override bool ShowWithoutActivation
        {
            get { return true; }
        }

        protected override CreateParams CreateParams
        {
            get
            {
                var parameters = base.CreateParams;
                parameters.ExStyle |= 0x08000000 | 0x00000080 | 0x00000020;
                return parameters;
            }
        }

        protected override void OnPaint(PaintEventArgs eventArgs)
        {
            base.OnPaint(eventArgs);
            eventArgs.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (var brush = new SolidBrush(Color.FromArgb(230, 40, 40, 42)))
            {
                eventArgs.Graphics.FillEllipse(brush, 1, 1, DotSize, DotSize);
            }
        }

        public void ShowDot(Point center)
        {
            var target = new Point(center.X - (Width / 2), center.Y - (Height / 2));
            if (Location != target)
            {
                Location = target;
            }

            if (!Visible)
            {
                Show();
            }
        }

        public void HideDot()
        {
            if (Visible)
            {
                Hide();
            }
        }
    }

    private static bool IsWeChatRunning()
    {
        var processes = Process.GetProcessesByName("Weixin");
        var running = processes.Length > 0;
        foreach (var process in processes)
        {
            process.Dispose();
        }
        return running;
    }

    private static Point DetectWeChatIcon()
    {
        var bounds = Screen.PrimaryScreen.Bounds;
        var scanHeight = Math.Min(340, bounds.Height);
        var scanTop = bounds.Bottom - scanHeight;
        var scanLeft = bounds.Left + (int)(bounds.Width * 0.18);
        var scanRight = bounds.Left + (int)(bounds.Width * 0.44);
        var scanWidth = Math.Max(1, scanRight - scanLeft);

        using (var bitmap = new Bitmap(scanWidth, scanHeight, PixelFormat.Format32bppArgb))
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.CopyFromScreen(scanLeft, scanTop, 0, 0, bitmap.Size, CopyPixelOperation.SourceCopy);
            var rectangle = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
            var data = bitmap.LockBits(rectangle, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try
            {
                var bytes = Math.Abs(data.Stride) * data.Height;
                var pixels = new byte[bytes];
                Marshal.Copy(data.Scan0, pixels, 0, bytes);
                long weightedX = 0;
                long weightedY = 0;
                var matches = 0;

                for (var y = 0; y < data.Height; y += 2)
                {
                    var row = y * data.Stride;
                    for (var x = 0; x < data.Width; x += 2)
                    {
                        var index = row + (x * 4);
                        var blue = pixels[index];
                        var green = pixels[index + 1];
                        var red = pixels[index + 2];
                        if (green >= 135 && green >= red + 42 && green >= blue + 26)
                        {
                            weightedX += x;
                            weightedY += y;
                            matches++;
                        }
                    }
                }

                if (matches < 80)
                {
                    return Point.Empty;
                }

                return new Point(
                    scanLeft + (int)(weightedX / matches),
                    scanTop + (int)(weightedY / matches));
            }
            finally
            {
                bitmap.UnlockBits(data);
            }
        }
    }

    private static bool TryGetDockRect(out Rect dockRect)
    {
        if (dockWindowHandle != IntPtr.Zero && IsWindow(dockWindowHandle))
        {
            Rect cachedRectangle;
            if (GetWindowRect(dockWindowHandle, out cachedRectangle) &&
                cachedRectangle.Right > cachedRectangle.Left &&
                cachedRectangle.Bottom > cachedRectangle.Top)
            {
                dockRect = cachedRectangle;
                return true;
            }
            dockWindowHandle = IntPtr.Zero;
        }

        var now = GetTickCount64();
        if (now - lastDockWindowSearch < DockWindowSearchIntervalMilliseconds)
        {
            dockRect = new Rect();
            return false;
        }
        lastDockWindowSearch = now;

        var found = new Rect();
        var foundHandle = IntPtr.Zero;
        var located = false;
        EnumWindows(delegate(IntPtr window, IntPtr parameter)
        {
            uint processId;
            GetWindowThreadProcessId(window, out processId);
            try
            {
                using (var process = Process.GetProcessById((int)processId))
                {
                    if (!string.Equals(process.ProcessName, "Dock_64", StringComparison.OrdinalIgnoreCase))
                    {
                        return true;
                    }
                }
            }
            catch
            {
                return true;
            }

            var className = new char[64];
            GetClassName(window, className, className.Length);
            var name = new string(className).TrimEnd('\0');
            Rect rectangle;
            if (name == "MyDockAPP" && GetWindowRect(window, out rectangle))
            {
                found = rectangle;
                foundHandle = window;
                located = true;
                return false;
            }
            return true;
        }, IntPtr.Zero);

        dockWindowHandle = foundHandle;
        dockRect = found;
        return located;
    }

    private static void Log(string message)
    {
        try
        {
            var folder = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "logs");
            Directory.CreateDirectory(folder);
            File.AppendAllText(
                Path.Combine(folder, "wechat-dock-dot.log"),
                DateTime.Now.ToString("s") + " " + message + Environment.NewLine);
        }
        catch
        {
        }
    }

    private delegate bool EnumWindowsCallback(IntPtr window, IntPtr parameter);

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsCallback callback, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(IntPtr window, char[] className, int maximumCount);

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr window, out Rect rectangle);

    [DllImport("user32.dll")]
    private static extern bool IsWindow(IntPtr window);

    [DllImport("user32.dll")]
    private static extern bool SetProcessDpiAwarenessContext(IntPtr value);

    [DllImport("kernel32.dll")]
    private static extern ulong GetTickCount64();
}
