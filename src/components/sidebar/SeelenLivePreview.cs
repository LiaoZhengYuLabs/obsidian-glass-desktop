using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Automation;
using System.Windows.Forms;

internal static class SeelenLivePreview
{
    private const int HoverDelayMs = 90;
    private const int PollMs = 30;

    [STAThread]
    private static void Main(string[] args)
    {
        Native.SetProcessDpiAwarenessContext(new IntPtr(-4));
        if (args.Length > 0 && args[0].Equals("/test:wechat", StringComparison.OrdinalIgnoreCase))
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new PreviewTestContext());
            return;
        }
        bool created;
        using (var mutex = new Mutex(true, "Local\\Obsidian.SeelenLivePreview.v1", out created))
        {
            if (!created) return;
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new PreviewContext());
        }
    }

    private sealed class PreviewTestContext : ApplicationContext
    {
        private readonly PreviewForm preview = new PreviewForm();
        private readonly System.Windows.Forms.Timer closeTimer;

        public PreviewTestContext()
        {
            var app = new AppItem
            {
                Id = "test.wechat",
                DisplayName = "微信 - 当前页面",
                Path = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                    "Tencent", "Weixin", "Weixin.exe")
            };
            List<WindowInfo> windows = Native.FindWindows(app);
            if (windows.Count == 0)
            {
                ExitThread();
                return;
            }
            preview.ShowPreview(app, windows, new Rectangle(0, 760, 72, 72));
            closeTimer = new System.Windows.Forms.Timer { Interval = 5000 };
            closeTimer.Tick += delegate
            {
                closeTimer.Stop();
                preview.HidePreview();
                preview.Dispose();
                ExitThread();
            };
            closeTimer.Start();
        }
    }

    private sealed class PreviewContext : ApplicationContext
    {
        private readonly System.Windows.Forms.Timer timer;
        private readonly PreviewForm preview = new PreviewForm();
        private readonly string statePath;
        private readonly string logPath;
        private DateTime nextUiRefresh = DateTime.MinValue;
        private DateTime nextWindowRefresh = DateTime.MinValue;
        private string refreshIdentity = "";
        private List<AppItem> apps = new List<AppItem>();
        private List<Rectangle> itemBounds = new List<Rectangle>();
        private AppItem pendingApp;
        private long hoverStarted;
        private long leaveStarted;
        private string shownSignature = "";
        private string lastHoverIdentity = "";
        private string lastMappingSignature = "";

        public PreviewContext()
        {
            string roaming = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            statePath = Path.Combine(roaming, "com.seelen.seelen-ui", "data", "seelen-weg", "state.yml");
            logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "logs", "seelen-live-preview.log");
            Directory.CreateDirectory(Path.GetDirectoryName(logPath));
            MainForm = preview;
            IntPtr previewHandle = preview.Handle;
            preview.Hide();
            RefreshSeelenItems();
            LogStartupMatches();
            timer = new System.Windows.Forms.Timer { Interval = PollMs };
            timer.Tick += Tick;
            timer.Start();
            Log("Neutral DWM live preview helper started.");
        }

        private void LogStartupMatches()
        {
            foreach (AppItem item in apps)
            {
                List<WindowInfo> matches = Native.FindWindows(item);
                if (matches.Count == 0)
                {
                    Log("Startup match: " + item.DisplayName + " -> none.");
                    continue;
                }
                WindowInfo window = matches[0];
                Native.Size source = preview.ProbeSourceSize(window.Handle);
                Log("Startup match: " + item.DisplayName + " -> " + window.ProcessName +
                    ", handle=" + window.Handle.ToInt64() + ", " + window.Bounds.Width + "x" + window.Bounds.Height +
                    ", DWM=" + source.Width + "x" + source.Height + ", minimized=" + window.Minimized +
                    ", title=" + window.Title + ".");
            }
        }

        private void Tick(object sender, EventArgs eventArgs)
        {
            try
            {
                DateTime now = DateTime.UtcNow;
                Point cursor = Cursor.Position;
                bool nearLeftTaskbar = cursor.X <= 150 || preview.Visible;
                if (nearLeftTaskbar && now >= nextUiRefresh)
                {
                    RefreshSeelenItems();
                    nextUiRefresh = now.AddMilliseconds(280);
                }
                else if (!nearLeftTaskbar && now >= nextUiRefresh)
                {
                    nextUiRefresh = now.AddSeconds(2);
                }

                int index = HitTest(cursor);
                AppItem hovered = index >= 0 && index < apps.Count ? apps[index] : null;
                bool overPreview = preview.Visible && preview.Bounds.Contains(cursor);

                if (hovered != null)
                {
                    if (lastHoverIdentity != hovered.Identity)
                    {
                        lastHoverIdentity = hovered.Identity;
                        Log("Hover detected: " + hovered.DisplayName + ".");
                    }
                    leaveStarted = 0;
                    if (pendingApp == null || pendingApp.Identity != hovered.Identity)
                    {
                        pendingApp = hovered;
                        hoverStarted = NowTicks();
                        shownSignature = "";
                    }
                    if (NowTicks() - hoverStarted >= HoverDelayMs)
                    {
                        ShowCurrentWindows(hovered, itemBounds[index]);
                    }
                }
                else if (!overPreview)
                {
                    lastHoverIdentity = "";
                    pendingApp = null;
                    hoverStarted = 0;
                    if (leaveStarted == 0) leaveStarted = NowTicks();
                    if (NowTicks() - leaveStarted >= 260)
                    {
                        preview.HidePreview();
                        shownSignature = "";
                    }
                }
                else
                {
                    leaveStarted = 0;
                }
            }
            catch (Exception ex)
            {
                Log("Tick failed: " + ex.Message);
            }
        }

        private void RefreshSeelenItems()
        {
            List<AppItem> parsed = ParseState(statePath);
            IntPtr weg = Native.FindTopLevelWindow("码头/任务栏", "seelen-ui");
            if (weg == IntPtr.Zero || parsed.Count == 0)
            {
                apps = parsed;
                itemBounds.Clear();
                LogMapping("WEG=" + weg.ToInt64() + ", apps=" + parsed.Count + ", bounds=0");
                return;
            }

            var root = AutomationElement.FromHandle(weg);
            var condition = new PropertyCondition(AutomationElement.ClassNameProperty, "weg-item-drag-container");
            var found = root.FindAll(TreeScope.Descendants, condition);
            var bounds = new List<Rectangle>();
            for (int i = 0; i < found.Count; i++)
            {
                var rectangle = found[i].Current.BoundingRectangle;
                if (double.IsInfinity(rectangle.X) || rectangle.Width < 20 || rectangle.Height < 20) continue;
                bounds.Add(new Rectangle(
                    (int)Math.Round(rectangle.X),
                    (int)Math.Round(rectangle.Y),
                    (int)Math.Round(rectangle.Width),
                    (int)Math.Round(rectangle.Height)));
            }
            bounds = bounds.OrderBy(item => item.Top).ToList();
            if (bounds.Count >= parsed.Count)
            {
                bounds = bounds.Skip(bounds.Count - parsed.Count).ToList();
            }
            apps = parsed;
            itemBounds = bounds;
            string positions = string.Join(";", bounds.Select(item => item.Left + "," + item.Top + "," + item.Width + "," + item.Height));
            LogMapping("WEG=" + weg.ToInt64() + ", apps=" + parsed.Count + ", bounds=" + bounds.Count + " [" + positions + "]");
        }

        private void LogMapping(string signature)
        {
            if (signature == lastMappingSignature) return;
            lastMappingSignature = signature;
            Log("Seelen mapping: " + signature);
        }

        private int HitTest(Point cursor)
        {
            int count = Math.Min(apps.Count, itemBounds.Count);
            for (int index = 0; index < count; index++)
            {
                if (itemBounds[index].Contains(cursor)) return index;
                if (itemBounds[index].Right <= 0 && cursor.X <= 18 &&
                    cursor.Y >= itemBounds[index].Top && cursor.Y <= itemBounds[index].Bottom)
                    return index;
            }
            return -1;
        }

        private static long NowTicks()
        {
            return (long)(uint)Environment.TickCount;
        }

        private void ShowCurrentWindows(AppItem app, Rectangle anchor)
        {
            bool sameApp = string.Equals(refreshIdentity, app.Identity, StringComparison.Ordinal);
            if (sameApp && DateTime.UtcNow < nextWindowRefresh && preview.Visible) return;
            refreshIdentity = app.Identity;
            nextWindowRefresh = DateTime.UtcNow.AddMilliseconds(220);
            List<WindowInfo> windows = Native.FindWindows(app);
            if (windows.Count == 0)
            {
                Log("No current window matched: " + app.DisplayName + " [" + app.Path + "].");
                preview.HidePreview();
                shownSignature = "";
                return;
            }

            string signature = app.Identity + "|" + string.Join("|", windows.Select(window =>
                window.Handle.ToInt64() + ":" + window.Title + ":" + window.Bounds.Width + "x" + window.Bounds.Height));
            if (signature == shownSignature && preview.Visible) return;
            shownSignature = signature;
            preview.ShowPreview(app, windows, anchor);
            Log("Preview refreshed: " + app.DisplayName + ", " + windows.Count + " current window(s).");
        }

        protected override void ExitThreadCore()
        {
            timer.Stop();
            timer.Dispose();
            preview.Dispose();
            base.ExitThreadCore();
        }

        private static List<AppItem> ParseState(string path)
        {
            var result = new List<AppItem>();
            if (!File.Exists(path)) return result;
            AppItem current = null;
            bool inCenter = false;
            foreach (string raw in File.ReadAllLines(path, Encoding.UTF8))
            {
                string line = raw.Trim();
                if (line == "center:") { inCenter = true; continue; }
                if (line.StartsWith("right:")) { if (current != null) result.Add(current); break; }
                if (!inCenter) continue;
                if (line == "- type: AppOrFile")
                {
                    if (current != null) result.Add(current);
                    current = new AppItem();
                    continue;
                }
                if (current == null) continue;
                if (line.StartsWith("displayName:")) current.DisplayName = Value(line);
                else if (line.StartsWith("path:")) current.Path = Value(line);
                else if (line.StartsWith("umid:")) current.Umid = Value(line);
                else if (line.StartsWith("id:")) current.Id = Value(line);
            }
            return result.Where(item => !string.IsNullOrWhiteSpace(item.Path)).ToList();
        }

        private static string Value(string line)
        {
            int colon = line.IndexOf(':');
            if (colon < 0) return "";
            string value = line.Substring(colon + 1).Trim().Trim('\'', '"');
            return value == "null" ? "" : value;
        }

        private void Log(string message)
        {
            try { File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff  ") + message + Environment.NewLine, Encoding.UTF8); }
            catch { }
        }
    }

    private sealed class PreviewForm : Form
    {
        private const int OuterPadding = 10;
        private const int HeaderHeight = 48;
        private const int FooterHeight = 34;
        private const int MaxPreviewWidth = 920;
        private const int MaxPreviewHeight = 700;
        private const int MinPreviewWidth = 420;
        private readonly List<IntPtr> thumbnails = new List<IntPtr>();
        private readonly List<Native.Size> sourceSizes = new List<Native.Size>();
        private readonly System.Windows.Forms.Timer fadeTimer;
        private List<WindowInfo> windows = new List<WindowInfo>();
        private AppItem app;
        private Rectangle thumbnailBounds = Rectangle.Empty;
        private Icon appIcon;

        public PreviewForm()
        {
            AutoScaleMode = AutoScaleMode.None;
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            BackColor = Color.FromArgb(42, 43, 47);
            Opacity = 0;
            DoubleBuffered = true;
            StartPosition = FormStartPosition.Manual;
            fadeTimer = new System.Windows.Forms.Timer { Interval = 16 };
            fadeTimer.Tick += delegate
            {
                Opacity = Math.Min(0.985, Opacity + 0.14);
                if (Opacity >= 0.985) fadeTimer.Stop();
            };
        }

        protected override bool ShowWithoutActivation { get { return true; } }
        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams value = base.CreateParams;
                value.ExStyle |= 0x08000000 | 0x00000080;
                return value;
            }
        }

        public void ShowPreview(AppItem currentApp, List<WindowInfo> currentWindows, Rectangle anchor)
        {
            ClearThumbnails();
            app = currentApp;
            windows = currentWindows.Take(1).ToList();
            if (windows.Count == 0) return;

            Rectangle work = Screen.FromRectangle(anchor).WorkingArea;
            Size = new Size(320, 220);
            Location = new Point(anchor.Right + 14, Math.Max(work.Top + 12, anchor.Top - 70));
            if (!Visible) Show();
            RegisterThumbnailHandles();

            Native.Size source = sourceSizes.Count > 0 ? sourceSizes[0] : new Native.Size();
            int sourceWidth = source.Width > 0 ? source.Width : Math.Max(1, windows[0].Bounds.Width);
            int sourceHeight = source.Height > 0 ? source.Height : Math.Max(1, windows[0].Bounds.Height);
            int availableWidth = Math.Max(320, work.Right - anchor.Right - 42);
            int maxWidth = Math.Min(MaxPreviewWidth, availableWidth);
            int maxHeight = Math.Min(MaxPreviewHeight, Math.Max(260, work.Height - HeaderHeight - FooterHeight - 36));
            double scale = Math.Min(maxWidth / (double)sourceWidth, maxHeight / (double)sourceHeight);
            int drawWidth = Math.Max(1, (int)Math.Round(sourceWidth * scale));
            int drawHeight = Math.Max(1, (int)Math.Round(sourceHeight * scale));

            if (drawWidth < MinPreviewWidth)
            {
                double enlarge = Math.Min(MinPreviewWidth / (double)drawWidth, maxHeight / (double)drawHeight);
                drawWidth = Math.Min(maxWidth, Math.Max(1, (int)Math.Round(drawWidth * enlarge)));
                drawHeight = Math.Min(maxHeight, Math.Max(1, (int)Math.Round(drawHeight * enlarge)));
            }

            thumbnailBounds = new Rectangle(OuterPadding, HeaderHeight, drawWidth, drawHeight);
            Size = new Size(drawWidth + OuterPadding * 2, HeaderHeight + drawHeight + FooterHeight);
            ApplyRoundedRegion();
            int x = Math.Min(work.Right - Width - 12, Math.Max(work.Left + 86, anchor.Right + 14));
            int y = Math.Max(work.Top + 12, Math.Min(work.Bottom - Height - 12, anchor.Top + anchor.Height / 2 - Height / 2));
            Location = new Point(x, y);
            Native.SetWindowPos(Handle, new IntPtr(-1), x, y, Width, Height, 0x0010 | 0x0040);
            UpdateThumbnailDestinations();
            LoadAppIcon();
            Invalidate();
            Opacity = 0;
            fadeTimer.Start();
        }

        public void HidePreview()
        {
            if (!Visible) return;
            fadeTimer.Stop();
            ClearThumbnails();
            Opacity = 0;
            Hide();
        }

        public Native.Size ProbeSourceSize(IntPtr sourceWindow)
        {
            IntPtr thumbnail;
            if (Native.DwmRegisterThumbnail(Handle, sourceWindow, out thumbnail) != 0 || thumbnail == IntPtr.Zero)
                return new Native.Size();
            try
            {
                Native.Size source;
                Native.DwmQueryThumbnailSourceSize(thumbnail, out source);
                return source;
            }
            finally
            {
                Native.DwmUnregisterThumbnail(thumbnail);
            }
        }

        private void RegisterThumbnailHandles()
        {
            foreach (WindowInfo window in windows)
            {
                IntPtr thumbnail;
                if (Native.DwmRegisterThumbnail(Handle, window.Handle, out thumbnail) != 0 || thumbnail == IntPtr.Zero) continue;
                Native.Size source;
                Native.DwmQueryThumbnailSourceSize(thumbnail, out source);
                thumbnails.Add(thumbnail);
                sourceSizes.Add(source);
            }
        }

        private void UpdateThumbnailDestinations()
        {
            if (thumbnails.Count == 0 || thumbnailBounds.Width <= 0 || thumbnailBounds.Height <= 0) return;
            var properties = new Native.ThumbnailProperties
            {
                Flags = 1 | 4 | 8 | 16,
                Destination = new Native.Rect
                {
                    Left = thumbnailBounds.Left,
                    Top = thumbnailBounds.Top,
                    Right = thumbnailBounds.Right,
                    Bottom = thumbnailBounds.Bottom
                },
                Opacity = 255,
                Visible = true,
                SourceClientAreaOnly = false
            };
            Native.DwmUpdateThumbnailProperties(thumbnails[0], ref properties);
        }

        private void ClearThumbnails()
        {
            foreach (IntPtr thumbnail in thumbnails) Native.DwmUnregisterThumbnail(thumbnail);
            thumbnails.Clear();
            sourceSizes.Clear();
        }

        private void LoadAppIcon()
        {
            if (appIcon != null) { appIcon.Dispose(); appIcon = null; }
            try
            {
                if (app != null && File.Exists(app.Path)) appIcon = Icon.ExtractAssociatedIcon(app.Path);
            }
            catch { }
        }

        private void ApplyRoundedRegion()
        {
            if (Width <= 0 || Height <= 0) return;
            using (var path = GraphicsExtensions.CreateRoundedPath(new Rectangle(0, 0, Width, Height), 16))
            {
                Region old = Region;
                Region = new Region(path);
                if (old != null) old.Dispose();
            }
        }

        protected override void OnPaint(PaintEventArgs eventArgs)
        {
            base.OnPaint(eventArgs);
            Graphics graphics = eventArgs.Graphics;
            graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            Rectangle card = new Rectangle(1, 1, Math.Max(1, Width - 3), Math.Max(1, Height - 3));
            using (var fill = new SolidBrush(Color.FromArgb(252, 42, 43, 47)))
                GraphicsExtensions.FillRoundedRectangle(graphics, fill, card, 16);
            using (var edge = new Pen(Color.FromArgb(215, 112, 115, 124), 1.2f))
                GraphicsExtensions.DrawRoundedRectangle(graphics, edge, card, 16);
            using (var separator = new Pen(Color.FromArgb(125, 101, 104, 112), 1f))
            {
                graphics.DrawLine(separator, OuterPadding, HeaderHeight - 1, Width - OuterPadding, HeaderHeight - 1);
                graphics.DrawLine(separator, OuterPadding, thumbnailBounds.Bottom, Width - OuterPadding, thumbnailBounds.Bottom);
            }
            using (var previewFill = new SolidBrush(Color.FromArgb(255, 16, 17, 20)))
                graphics.FillRectangle(previewFill, thumbnailBounds);

            if (appIcon != null) graphics.DrawIcon(appIcon, new Rectangle(14, 12, 24, 24));
            string appName = app == null || string.IsNullOrWhiteSpace(app.DisplayName) ? "应用" : app.DisplayName;
            using (var appFont = new Font("Microsoft YaHei UI", 10f, FontStyle.Bold))
            using (var titleFont = new Font("Microsoft YaHei UI", 8.5f, FontStyle.Regular))
            using (var statusFont = new Font("Microsoft YaHei UI", 8f, FontStyle.Regular))
            {
                TextRenderer.DrawText(graphics, appName, appFont,
                    new Rectangle(46, 8, Math.Max(1, Width - 60), 32), Color.FromArgb(245, 244, 245, 248),
                    TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.SingleLine);

                if (windows.Count == 0) return;
                TextRenderer.DrawText(graphics, windows[0].Title, titleFont,
                    new Rectangle(14, thumbnailBounds.Bottom + 3, Math.Max(1, Width - 82), FooterHeight - 6),
                    Color.FromArgb(220, 218, 220, 226),
                    TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.SingleLine);
                TextRenderer.DrawText(graphics, "实时", statusFont,
                    new Rectangle(Math.Max(1, Width - 58), thumbnailBounds.Bottom + 3, 44, FooterHeight - 6),
                    Color.FromArgb(205, 174, 220, 184),
                    TextFormatFlags.Right | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine);
            }
        }

        protected override void OnMouseDown(MouseEventArgs eventArgs)
        {
            base.OnMouseDown(eventArgs);
            if (windows.Count == 0) return;
            Native.ShowWindowAsync(windows[0].Handle, Native.IsIconic(windows[0].Handle) ? 9 : 5);
            Native.SetForegroundWindow(windows[0].Handle);
            HidePreview();
        }

        protected override void Dispose(bool disposing)
        {
            fadeTimer.Stop();
            fadeTimer.Dispose();
            if (appIcon != null) { appIcon.Dispose(); appIcon = null; }
            ClearThumbnails();
            base.Dispose(disposing);
        }
    }

    internal sealed class AppItem
    {
        public string Id = "";
        public string DisplayName = "";
        public string Path = "";
        public string Umid = "";
        public string Identity { get { return Id + "|" + Path; } }
    }

    internal sealed class WindowInfo
    {
        public IntPtr Handle;
        public string Title;
        public string ProcessName;
        public Rectangle Bounds;
        public int ZOrder;
        public bool Foreground;
        public bool Minimized;
    }

    private static class GraphicsExtensions
    {
        public static void FillRoundedRectangle(Graphics graphics, Brush brush, Rectangle bounds, int radius)
        {
            using (var path = CreateRoundedPath(bounds, radius)) graphics.FillPath(brush, path);
        }
        public static void DrawRoundedRectangle(Graphics graphics, Pen pen, Rectangle bounds, int radius)
        {
            using (var path = CreateRoundedPath(bounds, radius)) graphics.DrawPath(pen, path);
        }
        public static System.Drawing.Drawing2D.GraphicsPath CreateRoundedPath(Rectangle bounds, int radius)
        {
            int diameter = radius * 2;
            var path = new System.Drawing.Drawing2D.GraphicsPath();
            path.AddArc(bounds.Left, bounds.Top, diameter, diameter, 180, 90);
            path.AddArc(bounds.Right - diameter, bounds.Top, diameter, diameter, 270, 90);
            path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(bounds.Left, bounds.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    private static class Native
    {
        internal const int SW_RESTORE = 9;
        internal delegate bool EnumWindowsProc(IntPtr handle, IntPtr state);

        [StructLayout(LayoutKind.Sequential)] internal struct Rect { public int Left, Top, Right, Bottom; }
        [StructLayout(LayoutKind.Sequential)] internal struct Size { public int Width, Height; }
        [StructLayout(LayoutKind.Sequential)] internal struct NativePoint { public int X, Y; }
        [StructLayout(LayoutKind.Sequential)] internal struct WindowPlacement
        {
            public int Length;
            public int Flags;
            public int ShowCommand;
            public NativePoint MinimumPosition;
            public NativePoint MaximumPosition;
            public Rect NormalPosition;
        }
        [StructLayout(LayoutKind.Sequential)] internal struct ThumbnailProperties
        {
            public uint Flags; public Rect Destination; public Rect Source; public byte Opacity;
            [MarshalAs(UnmanagedType.Bool)] public bool Visible;
            [MarshalAs(UnmanagedType.Bool)] public bool SourceClientAreaOnly;
        }

        [DllImport("user32.dll")] internal static extern bool SetProcessDpiAwarenessContext(IntPtr value);
        [DllImport("user32.dll")] internal static extern bool EnumWindows(EnumWindowsProc callback, IntPtr state);
        [DllImport("user32.dll")] internal static extern bool IsWindowVisible(IntPtr handle);
        [DllImport("user32.dll")] internal static extern bool IsIconic(IntPtr handle);
        [DllImport("user32.dll")] internal static extern bool ShowWindowAsync(IntPtr handle, int command);
        [DllImport("user32.dll")] internal static extern bool SetForegroundWindow(IntPtr handle);
        [DllImport("user32.dll")] internal static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] internal static extern IntPtr GetWindow(IntPtr handle, uint command);
        [DllImport("user32.dll")] internal static extern bool GetWindowRect(IntPtr handle, out Rect rectangle);
        [DllImport("user32.dll")] internal static extern bool GetWindowPlacement(IntPtr handle, ref WindowPlacement placement);
        [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(IntPtr handle, out uint processId);
        [DllImport("user32.dll")] internal static extern bool SetWindowPos(IntPtr handle, IntPtr after, int x, int y, int width, int height, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] internal static extern int GetWindowText(IntPtr handle, StringBuilder text, int count);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] internal static extern int GetWindowTextLength(IntPtr handle);
        [DllImport("dwmapi.dll")] internal static extern int DwmRegisterThumbnail(IntPtr destination, IntPtr source, out IntPtr thumbnail);
        [DllImport("dwmapi.dll")] internal static extern int DwmUnregisterThumbnail(IntPtr thumbnail);
        [DllImport("dwmapi.dll")] internal static extern int DwmUpdateThumbnailProperties(IntPtr thumbnail, ref ThumbnailProperties properties);
        [DllImport("dwmapi.dll")] internal static extern int DwmQueryThumbnailSourceSize(IntPtr thumbnail, out Size size);
        [DllImport("dwmapi.dll")] private static extern int DwmGetWindowAttribute(IntPtr handle, int attribute, out int value, int size);
        [DllImport("dwmapi.dll", EntryPoint = "DwmGetWindowAttribute")]
        private static extern int DwmGetWindowAttributeRect(IntPtr handle, int attribute, out Rect value, int size);

        internal static IntPtr FindTopLevelWindow(string title, string processName)
        {
            IntPtr result = IntPtr.Zero;
            EnumWindows(delegate(IntPtr handle, IntPtr state)
            {
                uint pid; GetWindowThreadProcessId(handle, out pid);
                try
                {
                    Process process = Process.GetProcessById((int)pid);
                    if (string.Equals(process.ProcessName, processName, StringComparison.OrdinalIgnoreCase) && WindowTitle(handle) == title)
                    { result = handle; return false; }
                }
                catch { }
                return true;
            }, IntPtr.Zero);
            return result;
        }

        internal static List<WindowInfo> FindWindows(AppItem app)
        {
            var result = new List<WindowInfo>();
            IntPtr foreground = GetForegroundWindow();
            string expectedFile = System.IO.Path.GetFileNameWithoutExtension(app.Path) ?? "";
            bool isWeixin = expectedFile.Equals("Weixin", StringComparison.OrdinalIgnoreCase) ||
                app.DisplayName.Equals("微信", StringComparison.OrdinalIgnoreCase);
            int order = 0;
            EnumWindows(delegate(IntPtr handle, IntPtr state)
            {
                int z = order++;
                if (!IsWindowVisible(handle) || GetWindow(handle, 4) != IntPtr.Zero) return true;
                int cloaked = 0; try { DwmGetWindowAttribute(handle, 14, out cloaked, 4); } catch { }
                if (cloaked != 0) return true;
                string title = WindowTitle(handle);
                if (string.IsNullOrWhiteSpace(title)) return true;
                uint pid; GetWindowThreadProcessId(handle, out pid);
                Process process;
                try { process = Process.GetProcessById((int)pid); } catch { return true; }
                bool match = string.Equals(process.ProcessName, expectedFile, StringComparison.OrdinalIgnoreCase);
                if (!match && isWeixin)
                    match = process.ProcessName.Equals("WeChatAppEx", StringComparison.OrdinalIgnoreCase);
                if (!match && app.Umid.IndexOf("immersivecontrolpanel", StringComparison.OrdinalIgnoreCase) >= 0)
                    match = process.ProcessName.Equals("SystemSettings", StringComparison.OrdinalIgnoreCase) || title == "Settings";
                if (!match) return true;
                Rectangle bounds;
                if (!TryGetUsefulBounds(handle, out bounds)) return true;
                result.Add(new WindowInfo
                {
                    Handle = handle,
                    Title = title,
                    ProcessName = process.ProcessName,
                    Bounds = bounds,
                    ZOrder = z,
                    Foreground = handle == foreground,
                    Minimized = IsIconic(handle)
                });
                return true;
            }, IntPtr.Zero);

            if (result.Count == 0 && !string.IsNullOrWhiteSpace(expectedFile))
            {
                foreach (Process process in Process.GetProcessesByName(expectedFile))
                {
                    IntPtr handle = process.MainWindowHandle;
                    if (handle == IntPtr.Zero) continue;
                    Rectangle bounds;
                    if (!TryGetUsefulBounds(handle, out bounds)) continue;
                    string title = WindowTitle(handle);
                    if (string.IsNullOrWhiteSpace(title)) title = app.DisplayName;
                    result.Add(new WindowInfo
                    {
                        Handle = handle,
                        Title = title,
                        ProcessName = process.ProcessName,
                        Bounds = bounds,
                        ZOrder = 0,
                        Foreground = handle == foreground,
                        Minimized = IsIconic(handle)
                    });
                }
            }

            if (isWeixin)
            {
                result = result.OrderByDescending(item => item.Foreground)
                    .ThenByDescending(item => item.ProcessName.Equals("Weixin", StringComparison.OrdinalIgnoreCase))
                    .ThenByDescending(item => item.Title.Equals("微信", StringComparison.OrdinalIgnoreCase))
                    .ThenByDescending(item => item.Bounds.Width * (long)item.Bounds.Height)
                    .ThenBy(item => item.ZOrder)
                    .ToList();
            }
            else
            {
                result = result.OrderByDescending(item => item.Foreground)
                    .ThenBy(item => item.ZOrder)
                    .ThenByDescending(item => item.Bounds.Width * (long)item.Bounds.Height)
                    .ToList();
            }
            return result.Take(1).ToList();
        }

        private static bool TryGetUsefulBounds(IntPtr handle, out Rectangle bounds)
        {
            bounds = Rectangle.Empty;
            Rect rectangle;
            bool minimized = IsIconic(handle);

            if (!minimized)
            {
                try
                {
                    if (DwmGetWindowAttributeRect(handle, 9, out rectangle, Marshal.SizeOf(typeof(Rect))) == 0 &&
                        rectangle.Right - rectangle.Left >= 120 && rectangle.Bottom - rectangle.Top >= 80)
                    {
                        bounds = Rectangle.FromLTRB(rectangle.Left, rectangle.Top, rectangle.Right, rectangle.Bottom);
                        return true;
                    }
                }
                catch { }
            }

            var placement = new WindowPlacement { Length = Marshal.SizeOf(typeof(WindowPlacement)) };
            if (GetWindowPlacement(handle, ref placement))
            {
                rectangle = placement.NormalPosition;
                if (rectangle.Right - rectangle.Left >= 120 && rectangle.Bottom - rectangle.Top >= 80)
                {
                    bounds = Rectangle.FromLTRB(rectangle.Left, rectangle.Top, rectangle.Right, rectangle.Bottom);
                    return true;
                }
            }

            if (!GetWindowRect(handle, out rectangle)) return false;
            if (rectangle.Right - rectangle.Left < 120 || rectangle.Bottom - rectangle.Top < 80) return false;
            bounds = Rectangle.FromLTRB(rectangle.Left, rectangle.Top, rectangle.Right, rectangle.Bottom);
            return true;
        }

        private static string WindowTitle(IntPtr handle)
        {
            int length = GetWindowTextLength(handle);
            if (length <= 0) return "";
            var text = new StringBuilder(length + 1);
            GetWindowText(handle, text, text.Capacity);
            return text.ToString();
        }
    }
}
