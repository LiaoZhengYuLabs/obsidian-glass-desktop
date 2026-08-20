using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

internal static class WeChatDockPreview
{
    private const int HoverDelayMilliseconds = 500;
    private const int DetectionIntervalMilliseconds = 900;
    private const int TimerIntervalMilliseconds = 100;
    private const int PreviewWidth = 360;
    private const int PreviewHeight = 240;

    [STAThread]
    private static void Main()
    {
        bool created;
        using (var mutex = new Mutex(true, "Local\\ObsidianAIDock.WeChatDockPreview.v1", out created))
        {
            if (!created)
            {
                return;
            }

            SetProcessDpiAwarenessContext(new IntPtr(-4));
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new PreviewContext());
        }
    }

    private sealed class PreviewContext : ApplicationContext
    {
        private readonly PreviewForm preview = new PreviewForm();
        private readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
        private Point iconCenter = Point.Empty;
        private long lastDetection;
        private long hoverStarted;

        public PreviewContext()
        {
            timer.Interval = TimerIntervalMilliseconds;
            timer.Tick += Tick;
            timer.Start();
            Log("Preview helper started.");
        }

        private void Tick(object sender, EventArgs eventArgs)
        {
            var now = (long)GetTickCount64();
            if (now - lastDetection >= DetectionIntervalMilliseconds)
            {
                lastDetection = now;
                iconCenter = DetectWeChatIcon();
            }

            Point cursor;
            GetCursorPos(out cursor);
            var overIcon = iconCenter != Point.Empty &&
                           Math.Abs(cursor.X - iconCenter.X) <= 34 &&
                           Math.Abs(cursor.Y - iconCenter.Y) <= 100;

            if (!overIcon)
            {
                hoverStarted = 0;
                preview.HidePreview();
                return;
            }

            if (hoverStarted == 0)
            {
                hoverStarted = now;
                return;
            }

            if (now - hoverStarted >= HoverDelayMilliseconds)
            {
                preview.ShowPreview(iconCenter);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                timer.Stop();
                timer.Dispose();
                preview.Dispose();
            }
            base.Dispose(disposing);
        }
    }

    private sealed class PreviewForm : Form
    {
        private IntPtr thumbnail = IntPtr.Zero;
        private IntPtr sourceWindow = IntPtr.Zero;

        public PreviewForm()
        {
            AutoScaleMode = AutoScaleMode.None;
            ClientSize = new Size(PreviewWidth, PreviewHeight);
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            BackColor = Color.FromArgb(24, 25, 29);
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
                parameters.ExStyle |= 0x08000000 | 0x00000080;
                return parameters;
            }
        }

        protected override void OnPaint(PaintEventArgs eventArgs)
        {
            base.OnPaint(eventArgs);
            using (var border = new Pen(Color.FromArgb(100, 210, 220, 235)))
            using (var titleBrush = new SolidBrush(Color.FromArgb(235, 245, 248, 252)))
            using (var statusBrush = new SolidBrush(Color.FromArgb(155, 180, 192, 208)))
            using (var titleFont = new Font("Microsoft YaHei UI", 11, FontStyle.Bold))
            using (var statusFont = new Font("Microsoft YaHei UI", 8, FontStyle.Regular))
            {
                eventArgs.Graphics.DrawRectangle(border, 0, 0, ClientSize.Width - 1, ClientSize.Height - 1);
                eventArgs.Graphics.DrawString("\u5FAE\u4FE1", titleFont, titleBrush, 14, 10);
                eventArgs.Graphics.DrawString("LIVE WINDOW", statusFont, statusBrush, ClientSize.Width - 104, 13);
            }
        }

        public void ShowPreview(Point dockIconCenter)
        {
            var currentSource = FindWeChatWindow();
            if (currentSource == IntPtr.Zero)
            {
                HidePreview();
                return;
            }

            var screen = Screen.FromPoint(dockIconCenter).WorkingArea;
            var x = Math.Max(screen.Left + 8, Math.Min(screen.Right - Width - 8, dockIconCenter.X - (Width / 2)));
            var dockTop = FindDockTop(screen.Bottom);
            var y = Math.Max(screen.Top + 8, dockTop - Height - 14);
            Location = new Point(x, y);

            if (!Visible)
            {
                Show();
            }

            if (thumbnail == IntPtr.Zero || sourceWindow != currentSource)
            {
                ClearThumbnail();
                sourceWindow = currentSource;
                if (DwmRegisterThumbnail(Handle, sourceWindow, out thumbnail) != 0)
                {
                    thumbnail = IntPtr.Zero;
                    sourceWindow = IntPtr.Zero;
                    Hide();
                    return;
                }
            }

            var properties = new ThumbnailProperties();
            properties.Flags = 0x1D;
            properties.Destination = new Rect
            {
                Left = 12,
                Top = 38,
                Right = ClientSize.Width - 12,
                Bottom = ClientSize.Height - 12
            };
            properties.Opacity = 255;
            properties.Visible = true;
            properties.SourceClientAreaOnly = false;
            DwmUpdateThumbnailProperties(thumbnail, ref properties);
        }

        public void HidePreview()
        {
            if (Visible)
            {
                Hide();
            }
            ClearThumbnail();
        }

        private void ClearThumbnail()
        {
            if (thumbnail != IntPtr.Zero)
            {
                DwmUnregisterThumbnail(thumbnail);
                thumbnail = IntPtr.Zero;
            }
            sourceWindow = IntPtr.Zero;
        }

        protected override void Dispose(bool disposing)
        {
            ClearThumbnail();
            base.Dispose(disposing);
        }
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

    private static IntPtr FindWeChatWindow()
    {
        return Process.GetProcessesByName("Weixin")
            .Where(process => process.MainWindowHandle != IntPtr.Zero)
            .Select(process => process.MainWindowHandle)
            .FirstOrDefault();
    }

    private static int FindDockTop(int fallbackBottom)
    {
        var dockTop = fallbackBottom - 250;
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
                dockTop = rectangle.Top;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return dockTop;
    }

    private static void Log(string message)
    {
        try
        {
            var folder = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "logs");
            Directory.CreateDirectory(folder);
            File.AppendAllText(
                Path.Combine(folder, "wechat-dock-preview.log"),
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

    [StructLayout(LayoutKind.Sequential)]
    private struct ThumbnailProperties
    {
        public uint Flags;
        public Rect Destination;
        public Rect Source;
        public byte Opacity;
        [MarshalAs(UnmanagedType.Bool)] public bool Visible;
        [MarshalAs(UnmanagedType.Bool)] public bool SourceClientAreaOnly;
    }

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out Point point);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsCallback callback, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(IntPtr window, char[] className, int maximumCount);

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr window, out Rect rectangle);

    [DllImport("user32.dll")]
    private static extern bool SetProcessDpiAwarenessContext(IntPtr value);

    [DllImport("kernel32.dll")]
    private static extern ulong GetTickCount64();

    [DllImport("dwmapi.dll")]
    private static extern int DwmRegisterThumbnail(IntPtr destination, IntPtr source, out IntPtr thumbnail);

    [DllImport("dwmapi.dll")]
    private static extern int DwmUnregisterThumbnail(IntPtr thumbnail);

    [DllImport("dwmapi.dll")]
    private static extern int DwmUpdateThumbnailProperties(IntPtr thumbnail, ref ThumbnailProperties properties);
}
