using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

namespace ObsidianDockMediaProgress
{
    internal static class Program
    {
        private static Mutex instanceMutex;

        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [STAThread]
        private static void Main(string[] args)
        {
            bool created;
            instanceMutex = new Mutex(true, "Local\\ObsidianDockMediaProgress", out created);
            if (!created) return;

            SetProcessDPIAware();
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            string dockRoot = args.Length > 0
                ? args[0]
                : @"C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder";
            Application.Run(new MediaProgressForm(dockRoot));
        }
    }

    internal sealed class MediaProgressForm : Form
    {
        private const int WsExTransparent = 0x00000020;
        private const int WsExToolWindow = 0x00000080;
        private const int WsExNoActivate = 0x08000000;
        private const int DefaultFixedAppCount = 14;
        private readonly List<string> dockApps = new List<string>();
        private readonly System.Windows.Forms.Timer timer;
        private object manager;
        private DateTime managerRetryAfter = DateTime.MinValue;
        private double progressRatio;
        private bool playing;

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out NativePoint point);

        [StructLayout(LayoutKind.Sequential)]
        private struct NativePoint
        {
            public int X;
            public int Y;
        }

        internal MediaProgressForm(string dockRoot)
        {
            LoadDockApps(Path.Combine(dockRoot, "ico.ini"));
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            StartPosition = FormStartPosition.Manual;
            BackColor = Color.Magenta;
            TransparencyKey = Color.Magenta;
            ClientSize = new Size(62, 9);
            Location = new Point(-200, -200);
            Opacity = 0;

            SetStyle(ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint, true);

            timer = new System.Windows.Forms.Timer { Interval = 900 };
            timer.Tick += delegate { RefreshProgress(); };
        }

        protected override bool ShowWithoutActivation
        {
            get { return true; }
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams parameters = base.CreateParams;
                parameters.ExStyle |= WsExTransparent | WsExToolWindow | WsExNoActivate;
                return parameters;
            }
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            timer.Start();
            ThreadPool.QueueUserWorkItem(delegate { EnsureManager(); });
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;

            RectangleF track = new RectangleF(1, 2, ClientSize.Width - 2, 5);
            using (GraphicsPath trackPath = RoundedRect(track, 2.5f))
            using (var trackBrush = new SolidBrush(Color.FromArgb(76, 225, 234, 244)))
            using (var edgePen = new Pen(Color.FromArgb(118, 255, 255, 255), 0.8f))
            {
                e.Graphics.FillPath(trackBrush, trackPath);
                e.Graphics.DrawPath(edgePen, trackPath);
            }

            float width = Math.Max(2, (float)((ClientSize.Width - 2) * progressRatio));
            RectangleF value = new RectangleF(1, 2, width, 5);
            using (GraphicsPath valuePath = RoundedRect(value, 2.5f))
            using (var brush = new LinearGradientBrush(
                value,
                playing ? Color.FromArgb(255, 132, 220, 255) : Color.FromArgb(215, 185, 218, 235),
                Color.FromArgb(255, 245, 250, 255),
                LinearGradientMode.Horizontal))
            {
                e.Graphics.FillPath(brush, valuePath);
            }
        }

        private static GraphicsPath RoundedRect(RectangleF rectangle, float radius)
        {
            float diameter = radius * 2;
            var path = new GraphicsPath();
            path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }

        private void EnsureManager()
        {
            if (manager != null || DateTime.UtcNow < managerRetryAfter) return;
            try
            {
                Type managerType = Type.GetType(
                    "Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media, ContentType=WindowsRuntime",
                    true);
                MethodInfo request = managerType.GetMethod("RequestAsync", BindingFlags.Public | BindingFlags.Static);
                object operation = request.Invoke(null, null);
                Type resultType = request.ReturnType.GetGenericArguments()[0];
                MethodInfo bridge = null;

                foreach (MethodInfo candidate in typeof(System.WindowsRuntimeSystemExtensions).GetMethods())
                {
                    if (candidate.Name == "AsTask" &&
                        candidate.IsGenericMethodDefinition &&
                        candidate.GetGenericArguments().Length == 1 &&
                        candidate.GetParameters().Length == 1)
                    {
                        bridge = candidate.MakeGenericMethod(resultType);
                        break;
                    }
                }

                if (bridge == null) throw new InvalidOperationException("WinRT task bridge missing.");
                object task = bridge.Invoke(null, new[] { operation });
                object awaiter = task.GetType().GetMethod("GetAwaiter").Invoke(task, null);
                manager = awaiter.GetType().GetMethod("GetResult").Invoke(awaiter, null);
            }
            catch
            {
                manager = null;
                managerRetryAfter = DateTime.UtcNow.AddSeconds(20);
            }
        }

        private void RefreshProgress()
        {
            if (manager == null)
            {
                HideProgress();
                ThreadPool.QueueUserWorkItem(delegate { EnsureManager(); });
                return;
            }

            if (!PointerNearDock())
            {
                HideProgress();
                return;
            }

            try
            {
                object session = Invoke(manager, "GetCurrentSession");
                if (session == null)
                {
                    HideProgress();
                    return;
                }

                object timeline = Invoke(session, "GetTimelineProperties");
                object playback = Invoke(session, "GetPlaybackInfo");
                TimeSpan start = (TimeSpan)GetProperty(timeline, "StartTime");
                TimeSpan end = (TimeSpan)GetProperty(timeline, "EndTime");
                TimeSpan position = (TimeSpan)GetProperty(timeline, "Position");
                DateTimeOffset updated = (DateTimeOffset)GetProperty(timeline, "LastUpdatedTime");
                string state = GetProperty(playback, "PlaybackStatus").ToString();
                string source = (string)GetProperty(session, "SourceAppUserModelId");
                double duration = (end - start).TotalSeconds;

                if (duration <= 1)
                {
                    HideProgress();
                    return;
                }

                double elapsed = (position - start).TotalSeconds;
                playing = String.Equals(state, "Playing", StringComparison.OrdinalIgnoreCase);
                if (playing) elapsed += Math.Max(0, (DateTimeOffset.Now - updated).TotalSeconds);

                int dockIndex = FindDockIndex(source);
                if (dockIndex <= 0)
                {
                    HideProgress();
                    return;
                }

                progressRatio = Math.Max(0, Math.Min(1, elapsed / duration));
                PositionBelowIcon(dockIndex);
                Opacity = playing ? 0.96 : 0.72;
                Invalidate();
            }
            catch
            {
                manager = null;
                managerRetryAfter = DateTime.UtcNow.AddSeconds(10);
                HideProgress();
            }
        }

        private static object Invoke(object target, string method)
        {
            return target.GetType().GetMethod(method).Invoke(target, null);
        }

        private static object GetProperty(object target, string property)
        {
            return target.GetType().GetProperty(property).GetValue(target, null);
        }

        private static bool PointerNearDock()
        {
            NativePoint point;
            if (!GetCursorPos(out point)) return false;
            Rectangle screen = Screen.PrimaryScreen.Bounds;
            return point.X >= screen.Left && point.X <= screen.Right && point.Y >= screen.Bottom - 300;
        }

        private void HideProgress()
        {
            if (Opacity != 0) Opacity = 0;
            if (Left != -200 || Top != -200) Location = new Point(-200, -200);
        }

        private void PositionBelowIcon(int oneBasedIndex)
        {
            Rectangle screen = Screen.PrimaryScreen.Bounds;
            int iconCount = Math.Max(1, dockApps.Count);
            const double slot = 84;
            const double separatorGap = 28;
            double totalWidth = iconCount * slot + separatorGap + 52;
            double dockLeft = screen.Left + (screen.Width - totalWidth) / 2;
            double center = dockLeft + 26 + (oneBasedIndex - 0.5) * slot;
            if (oneBasedIndex > DefaultFixedAppCount) center += separatorGap;
            Location = new Point((int)Math.Round(center - ClientSize.Width / 2.0), screen.Bottom - ClientSize.Height - 4);
        }

        private int FindDockIndex(string source)
        {
            if (String.IsNullOrWhiteSpace(source)) return -1;
            string normalized = Normalize(source);
            string[] aliases;

            if (normalized.Contains("chrome")) aliases = new[] { "googlechrome", "chrome" };
            else if (normalized.Contains("edge")) aliases = new[] { "microsoftedge", "edge" };
            else if (normalized.Contains("wechat") || normalized.Contains("weixin")) aliases = new[] { "wechat", "weixin", "微信" };
            else if (normalized.Contains("cine") || normalized.Contains("movie")) aliases = new[] { "cinegate", "cine" };
            else if (normalized.Contains("spotify")) aliases = new[] { "spotify" };
            else if (normalized.Contains("vlc")) aliases = new[] { "vlc" };
            else if (normalized.Contains("zunemusic") || normalized.Contains("mediaplayer")) aliases = new[] { "mediaplayer", "播放器" };
            else aliases = new[] { normalized };

            for (int i = 0; i < dockApps.Count; i++)
            {
                string app = Normalize(dockApps[i]);
                if (String.IsNullOrEmpty(app)) continue;
                foreach (string alias in aliases)
                {
                    string value = Normalize(alias);
                    if (app.Contains(value) || normalized.Contains(app)) return i + 1;
                }
            }
            return -1;
        }

        private void LoadDockApps(string path)
        {
            if (!File.Exists(path)) return;
            try
            {
                string sectionNumber = null;
                var entries = new SortedDictionary<int, string>();
                foreach (string rawLine in File.ReadAllLines(path))
                {
                    string line = rawLine.Trim();
                    Match section = Regex.Match(line, @"^\[ico(\d+)\]$", RegexOptions.IgnoreCase);
                    if (section.Success)
                    {
                        sectionNumber = section.Groups[1].Value;
                        continue;
                    }

                    if (sectionNumber != null && line.StartsWith("appname=", StringComparison.OrdinalIgnoreCase))
                    {
                        int number;
                        if (Int32.TryParse(sectionNumber, out number)) entries[number] = line.Substring(8).Trim();
                    }
                }

                int maximum = 0;
                foreach (int key in entries.Keys) maximum = Math.Max(maximum, key);
                for (int index = 1; index <= maximum; index++)
                {
                    string app;
                    dockApps.Add(entries.TryGetValue(index, out app) ? app : String.Empty);
                }
            }
            catch
            {
                dockApps.Clear();
            }
        }

        private static string Normalize(string value)
        {
            if (String.IsNullOrEmpty(value)) return String.Empty;
            return Regex.Replace(value.ToLowerInvariant(), @"[^a-z0-9\u4e00-\u9fff]+", String.Empty);
        }
    }
}
