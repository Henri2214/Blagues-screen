# ============================================================
#  NIAH! NIAH! NIAH!  -  lettres 3D fantaisie qui ondulent en profondeur
#  et changent de matiere en boucle :
#     bois clair -> bois fonce -> or -> alu -> cuivre -> feuilles -> eau -> ...
#  - rendu WPF anti-aliase, textures generees, tranche 3D, ombre douce
#  - la transition de matiere se propage d'une lettre a l'autre comme une vague
#  - rebondit sur tous les ecrans (2, 3 ou plus)
#  - fenetre "click-through" : ne gene pas la souris
#  - le Gestionnaire des taches reste accessible (Ctrl+Maj+Echap -> powershell.exe)
#  - s'arrete tout seul apres -Minutes minutes (15 par defaut)
#  Usage : powershell -ExecutionPolicy Bypass -File nia.ps1 [-Minutes 30] [-Speed 3] [-Size 190] [-Wave 40]
#                     [-MatSeconds 5] [-Font "Jokerman"] [-Text "NIAH! NIAH! NIAH!"]
#  Polices fun possibles : Cooper Black, Showcard Gothic, Bauhaus 93, Jokerman, Snap ITC, Ravie, Segoe Print
#  (la premiere installee de la liste -Font est utilisee)
# ============================================================
param(
    [int]$Minutes     = 15,
    [double]$Speed    = 3,       # vitesse de deplacement (1 = tres lent, 3 = tranquille, 8 = rapide)
    [double]$Size     = 190,     # taille de la police (reduite automatiquement si ca depasse du plus petit ecran)
    [double]$Wave     = 40,      # amplitude verticale de la vague
    [double]$MatSeconds = 5,     # duree de chaque matiere (transition comprise)
    [string]$Font     = "Cooper Black, Showcard Gothic, Bauhaus 93, Segoe Print, Comic Sans MS",
    [string]$Text     = "NIAH! NIAH! NIAH!",
    # Phrases affichees en haut de chaque ecran (le texte entre *etoiles* est mis en valeur)
    [string[]]$Messages = @(
        "NIAH NIAH NIAH ! Quelqu'un a oublié *Windows + L* avant sa pause...",
        "Un PC non verrouillé, c'est un PC qui fait des blagues tout seul. *Windows + L* !",
        "Astuce sécurité du jour : *Windows + L*. Sinon... NIAH.",
        "Session ouverte = porte ouverte. La prochaine fois : *Windows + L* !",
        "Ce PC a été laissé sans surveillance. Les lettres en bois ont pris le pouvoir. *Windows + L* !"
    )
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms, System.Drawing

$code = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;

public static class NiahLog
{
    // ---------- bandeau de rappel en haut de chaque ecran ----------
    static List<Window> bwins = new List<Window>();
    static List<TextBlock> btxt = new List<TextBlock>();
    static string[] bmsgs;
    static int bcur = -1;
    static double bop = -1;

    static void BannerInit(string[] msgs)
    {
        bmsgs = (msgs == null || msgs.Length == 0) ? new string[] { "Pense a *Windows + L* avant la pause !" } : msgs;
        foreach (System.Windows.Forms.Screen scr in System.Windows.Forms.Screen.AllScreens)
        {
            System.Drawing.Rectangle area = scr.WorkingArea;
            TextBlock tb = new TextBlock();
            tb.FontFamily = new FontFamily("Segoe UI");
            tb.FontSize = 20; tb.FontWeight = FontWeights.SemiBold; tb.Foreground = Brushes.White;
            Border bd = new Border();
            bd.CornerRadius = new CornerRadius(16);
            bd.Padding = new Thickness(22, 8, 22, 10);
            bd.Background = new SolidColorBrush(Color.FromArgb(205, 20, 22, 28));
            bd.BorderBrush = new SolidColorBrush(Color.FromArgb(110, 255, 255, 255));
            bd.BorderThickness = new Thickness(1);
            DropShadowEffect ds = new DropShadowEffect(); ds.BlurRadius = 14; ds.ShadowDepth = 3; ds.Opacity = 0.5;
            bd.Effect = ds;
            bd.Child = tb;
            Grid g = new Grid(); g.Margin = new Thickness(18); g.Children.Add(bd);
            g.IsHitTestVisible = false;

            Window w = new Window();
            w.WindowStyle = WindowStyle.None; w.AllowsTransparency = true; w.Background = Brushes.Transparent;
            w.Topmost = true; w.ShowInTaskbar = false; w.ShowActivated = false; w.ResizeMode = ResizeMode.NoResize;
            w.WindowStartupLocation = WindowStartupLocation.Manual; w.Left = -30000; w.Top = -30000;
            w.SizeToContent = SizeToContent.WidthAndHeight;
            w.Content = g; w.Opacity = 0;
            w.SourceInitialized += delegate
            {
                IntPtr h = new WindowInteropHelper(w).Handle;
                SetWindowLong(h, -20, GetWindowLong(h, -20) | 0x20 | 0x80 | 0x08000000);  // click-through
            };
            w.Loaded += delegate { PlaceBanner(w, area); };
            w.SizeChanged += delegate { PlaceBanner(w, area); };
            bwins.Add(w); btxt.Add(tb);
            w.Show();
        }
    }
    static void PlaceBanner(Window w, System.Drawing.Rectangle a)
    {
        IntPtr h = new WindowInteropHelper(w).Handle;
        if (h == IntPtr.Zero) return;
        RECT r; GetWindowRect(h, out r);
        int ww = r.R - r.L;
        SetWindowPos(h, new IntPtr(-1), a.X + (a.Width - ww) / 2, a.Y, 0, 0, 0x0001 | 0x0010);
    }
    static void SetMsg(TextBlock tb, string m)
    {
        tb.Inlines.Clear();
        string[] parts = m.Split('*');
        for (int i = 0; i < parts.Length; i++)
        {
            System.Windows.Documents.Run r = new System.Windows.Documents.Run(parts[i]);
            if (i % 2 == 1) { r.Foreground = new SolidColorBrush(Color.FromRgb(255, 206, 60)); r.FontWeight = FontWeights.Bold; }
            tb.Inlines.Add(r);
        }
    }
    static void BannerTick(double t)
    {
        double period = 9;
        int idx = (int)Math.Floor(t / period) % bmsgs.Length;
        double f = t % period;
        double op = Math.Max(0, Math.Min(1, Math.Min(f / 0.7, (period - f) / 0.7)));
        if (idx != bcur) { bcur = idx; foreach (TextBlock tb in btxt) SetMsg(tb, bmsgs[idx]); }
        if (Math.Abs(op - bop) > 0.01) { bop = op; foreach (Window w in bwins) w.Opacity = op; }
    }

    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);

    // ---------- matieres ----------
    const int WOOD = 0, BARK = 1, METAL = 2, LEAF = 3, WATER = 4;
    class Mat
    {
        public int FaceKind, SideKind;
        public Color F0, F1, S0, S1;     // couleur claire (k=0) -> foncee (k=1)
        public double Shine;             // 0 = mat, 1 = tres brillant
        public BitmapSource FaceTex, SideTex;
    }
    static Mat M(int fk, Color f0, Color f1, int sk, Color s0, Color s1, double shine)
    {
        Mat m = new Mat();
        m.FaceKind = fk; m.F0 = f0; m.F1 = f1; m.SideKind = sk; m.S0 = s0; m.S1 = s1; m.Shine = shine;
        return m;
    }

    class Glyph
    {
        public Rect Bounds;
        public double W, H;
        public BitmapSource[] Bmps;
    }

    class Letter
    {
        public FrameworkElement El;
        public ScaleTransform S;
        public SkewTransform K;
        public TranslateTransform T;
        public Rectangle Dark;
        public Image[] Imgs;
        public int Index;
        public int Z = int.MinValue, Cur = -1, Nxt = -1;
    }

    static List<Letter> letters = new List<Letter>();
    static System.Drawing.Rectangle[] screens;
    static IntPtr hwnd;
    static Window win;
    static Stopwatch sw;
    static double px, py, vx, vy, amp, endT, lastT, lastFrame, matPeriod;
    static int pw, ph, nMats;

    // ---------- bruit ----------
    static double Hash(int x, int y, int seed)
    {
        unchecked
        {
            int n = x * 374761393 + y * 668265263 + seed * 144269;
            n = (n ^ (n >> 13)) * 1274126177;
            n = n ^ (n >> 16);
            return (n & 0x7fffffff) / 2147483647.0;
        }
    }
    static double Lerp(double a, double b, double t) { return a + (b - a) * t; }
    static double Clamp01(double v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
    static double Noise(double x, double y, int seed)
    {
        int xi = (int)Math.Floor(x), yi = (int)Math.Floor(y);
        double fx = x - xi, fy = y - yi;
        fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
        double a = Hash(xi, yi, seed), b = Hash(xi + 1, yi, seed);
        double c = Hash(xi, yi + 1, seed), d = Hash(xi + 1, yi + 1, seed);
        return Lerp(Lerp(a, b, fx), Lerp(c, d, fx), fy);
    }
    static double Fbm(double x, double y, int seed)
    {
        double s = 0, a = 0.5;
        for (int o = 0; o < 4; o++) { s += a * Noise(x, y, seed + o * 17); x *= 2; y *= 2; a *= 0.5; }
        return s / 0.9375;
    }
    static byte Bt(double v) { return (byte)(v < 0 ? 0 : (v > 255 ? 255 : v)); }

    // Feuillage : cellules de Voronoi = feuilles, avec nervure centrale et interstices sombres
    static double LeafK(int x, int y)
    {
        double cs = 44.0;
        double gx = x / cs, gy = y / cs;
        int cx = (int)Math.Floor(gx), cy = (int)Math.Floor(gy);
        double d1 = 9, d2 = 9, sx = 0, sy = 0; int bx = 0, by = 0;
        for (int j = -1; j <= 1; j++)
        for (int i = -1; i <= 1; i++)
        {
            int ix = cx + i, iy = cy + j;
            double qx = ix + Hash(ix, iy, 31), qy = iy + Hash(ix, iy, 47);
            double d = Math.Sqrt((gx - qx) * (gx - qx) + (gy - qy) * (gy - qy));
            if (d < d1) { d2 = d1; d1 = d; bx = ix; by = iy; sx = qx; sy = qy; }
            else if (d < d2) d2 = d;
        }
        double edge = d2 - d1;
        double tone = Hash(bx, by, 59);
        double mott = Fbm(x * 0.03, y * 0.03, 61);
        double k = 0.12 + tone * 0.45 + (mott - 0.5) * 0.3 + d1 * 0.3;
        double th = Hash(bx, by, 71) * Math.PI;
        double vein = Math.Abs((gx - sx) * Math.Sin(th) - (gy - sy) * Math.Cos(th));
        if (vein < 0.035 && d1 < 0.45) k -= 0.28;
        if (edge < 0.07) k = 0.97 - edge * 4;
        return Clamp01(k);
    }

    static double TexK(int kind, int x, int y, int h)
    {
        switch (kind)
        {
            case WOOD:
            {
                double n = Fbm(x * 0.008, y * 0.035, 1);
                double t = y * 0.035 + n * 4.5 + Math.Sin(x * 0.006) * 0.8;
                double band = Math.Pow(0.5 + 0.5 * Math.Sin(t * Math.PI * 2), 3);
                double fiber = Fbm(x * 0.0025, y * 0.45, 9) - 0.5;
                return Clamp01(band * 0.55 + fiber * 0.55 + 0.18);
            }
            case BARK:
            {
                double n = Fbm(x * 0.05, y * 0.012, 3);
                double cre = Math.Pow(Math.Abs(Math.Sin(n * 15)), 0.55);
                return Clamp01(1 - cre + (Hash(x, y, 5) - 0.5) * 0.12);
            }
            case METAL:
            {
                double k = 0.45 + (Fbm(x * 0.0015, y * 0.5, 11) - 0.5) * 0.7
                                + (Fbm(x * 0.006, y * 0.006, 4) - 0.5) * 0.45
                                + (Hash(x, y, 3) - 0.5) * 0.05;
                return Clamp01(k);
            }
            case LEAF:
                return LeafK(x, y);
            default: // WATER : caustiques
            {
                double n1 = Fbm(x * 0.008, y * 0.008, 21), n2 = Fbm(x * 0.011 + 5, y * 0.009 + 3, 33);
                double c1 = Math.Pow(1 - Math.Abs(Math.Sin(n1 * 18)), 8);
                double c2 = Math.Pow(1 - Math.Abs(Math.Sin(n2 * 18)), 8);
                double k = 0.3 + (double)y / h * 0.45 - (c1 + c2) * 0.6 + (Fbm(x * 0.02, y * 0.02, 41) - 0.5) * 0.2;
                return Clamp01(k);
            }
        }
    }

    static BitmapSource MakeTex(int w, int h, int kind, Color c0, Color c1)
    {
        byte[] buf = new byte[w * h * 4];
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            double k = TexK(kind, x, y, h);
            int i = (y * w + x) * 4;
            buf[i]     = Bt(Lerp(c0.B, c1.B, k));
            buf[i + 1] = Bt(Lerp(c0.G, c1.G, k));
            buf[i + 2] = Bt(Lerp(c0.R, c1.R, k));
            buf[i + 3] = 255;
        }
        BitmapSource bs = BitmapSource.Create(w, h, 96, 96, PixelFormats.Bgra32, null, buf, w * 4);
        bs.Freeze();
        return bs;
    }

    static Color C(int a, int r, int g, int b) { return Color.FromArgb((byte)a, (byte)r, (byte)g, (byte)b); }
    static Color C(int r, int g, int b) { return Color.FromArgb(255, (byte)r, (byte)g, (byte)b); }
    static int A(double v) { return (int)(v < 0 ? 0 : (v > 255 ? 255 : v)); }

    static LinearGradientBrush Grad(Point p0, Point p1, params object[] stops)
    {
        LinearGradientBrush lg = new LinearGradientBrush();
        lg.StartPoint = p0; lg.EndPoint = p1;
        for (int i = 0; i < stops.Length; i += 2) lg.GradientStops.Add(new GradientStop((Color)stops[i + 1], (double)stops[i]));
        return lg;
    }

    static ImageBrush Tile(BitmapSource tex, Rect b, Random rnd)
    {
        ImageBrush ib = new ImageBrush(tex);
        ib.TileMode = TileMode.Tile; ib.ViewportUnits = BrushMappingMode.Absolute; ib.Stretch = Stretch.Fill;
        double tw = tex.PixelWidth, th = tex.PixelHeight;
        ib.Viewport = new Rect(b.X - rnd.Next(0, (int)(tw * 0.4)), b.Y - rnd.Next(0, (int)(th * 0.4)), tw, th);
        return ib;
    }

    static FormattedText Ft(string s, Typeface tf, double size)
    {
        return new FormattedText(s, CultureInfo.InvariantCulture, FlowDirection.LeftToRight, tf, size, Brushes.Black);
    }

    static bool Inside(double x, double y)
    {
        int x0 = (int)x, y0 = (int)y, x1 = x0 + pw - 1, y1 = y0 + ph - 1;
        return InAny(x0, y0) && InAny(x1, y0) && InAny(x0, y1) && InAny(x1, y1);
    }
    static bool InAny(int x, int y)
    {
        foreach (System.Drawing.Rectangle r in screens) if (r.Contains(x, y)) return true;
        return false;
    }

    public static void Run(string text, double fontSize, double speed, double wave, double minutes, double matSeconds, string fontList, string[] msgs)
    {
        try { SetProcessDPIAware(); } catch { }
        double dpi;
        using (System.Drawing.Graphics gr = System.Drawing.Graphics.FromHwnd(IntPtr.Zero)) dpi = gr.DpiX / 96.0;

        System.Windows.Forms.Screen[] all = System.Windows.Forms.Screen.AllScreens;
        screens = new System.Drawing.Rectangle[all.Length];
        int minW = int.MaxValue, minH = int.MaxValue;
        for (int i = 0; i < all.Length; i++)
        {
            screens[i] = all[i].Bounds;
            minW = Math.Min(minW, screens[i].Width);
            minH = Math.Min(minH, screens[i].Height);
        }
        double maxW = minW / dpi * 0.92, maxH = minH / dpi * 0.8;

        Typeface tf = new Typeface(new FontFamily(fontList), FontStyles.Normal, FontWeights.Bold, FontStretches.Normal);

        // Ajuste la taille pour tenir dans le plus petit ecran
        double total;
        while (true)
        {
            total = 0;
            foreach (char ch0 in text) total += Ft(ch0.ToString(), tf, fontSize).WidthIncludingTrailingWhitespace;
            double w = total + fontSize * 0.95;
            double h = 2 * (wave + fontSize * 0.3) + fontSize * 1.5;
            if ((w <= maxW && h <= maxH) || fontSize <= 40) break;
            fontSize -= 6;
        }
        amp = wave;
        matPeriod = Math.Max(1.5, matSeconds);

        // bois clair -> bois fonce -> or -> alu -> cuivre -> feuilles -> eau
        Mat[] mats = new Mat[] {
            M(WOOD,  C(240, 206, 150), C(176, 120, 64), BARK,  C(130, 90, 54),  C(52, 32, 16),  0.35),
            M(WOOD,  C(150, 92, 52),   C(56, 28, 12),   BARK,  C(84, 52, 30),   C(26, 15, 7),   0.30),
            M(METAL, C(255, 230, 130), C(176, 120, 22), METAL, C(156, 104, 22), C(70, 45, 6),   1.00),
            M(METAL, C(242, 246, 250), C(142, 150, 160),METAL, C(130, 138, 148),C(58, 64, 72),  0.90),
            M(METAL, C(252, 184, 134), C(166, 82, 40),  METAL, C(140, 64, 30),  C(60, 25, 10),  0.90),
            M(LEAF,  C(172, 226, 92),  C(28, 96, 28),   LEAF,  C(46, 100, 30),  C(12, 40, 10),  0.40),
            M(WATER, C(196, 242, 255), C(10, 92, 184),  WATER, C(24, 92, 172),  C(4, 30, 82),   0.70)
        };
        nMats = mats.Length;
        foreach (Mat m in mats)
        {
            m.FaceTex = MakeTex(512, 512, m.FaceKind, m.F0, m.F1);
            m.SideTex = MakeTex(256, 256, m.SideKind, m.S0, m.S1);
        }

        double padX = fontSize * 0.42, padY = wave + fontSize * 0.3;
        double depth = fontSize * 0.15, ddx = depth * 0.45, ddy = depth;
        int steps = 18;
        double margin = fontSize * 0.3;
        double rs = dpi * 1.3;                     // sur-echantillonnage pour rester net quand la lettre grossit
        double lineH = Ft("N", tf, fontSize).Height;
        Random rnd = new Random(7);
        Dictionary<char, Glyph> cache = new Dictionary<char, Glyph>();

        Canvas canvas = new Canvas();
        canvas.IsHitTestVisible = false;

        double cursor = 0;
        int idx = 0;
        foreach (char c in text)
        {
            FormattedText ft = Ft(c.ToString(), tf, fontSize);
            double adv = ft.WidthIncludingTrailingWhitespace;
            Glyph gl = null;
            if (!char.IsWhiteSpace(c) && !cache.TryGetValue(c, out gl))
            {
                Geometry face = ft.BuildGeometry(new Point(0, 0));
                Rect b = (face == null) ? Rect.Empty : face.Bounds;
                if (!b.IsEmpty)
                {
                    // Extrusion : union de copies decalees -> tranche 3D
                    Geometry side = face.Clone();
                    for (int k = 1; k <= steps; k++)
                    {
                        Geometry g = face.Clone();
                        g.Transform = new TranslateTransform(ddx * k / steps, ddy * k / steps);
                        side = Geometry.Combine(side, g, GeometryCombineMode.Union, null);
                    }
                    gl = new Glyph();
                    gl.Bounds = b;
                    gl.W = b.Width + ddx + 2 * margin;
                    gl.H = b.Height + ddy + 2 * margin;
                    gl.Bmps = new BitmapSource[nMats];

                    for (int mi = 0; mi < nMats; mi++)
                    {
                        Mat m = mats[mi];
                        double sh = m.Shine;
                        Brush sideShade = Grad(new Point(0, 0), new Point(1, 1), 0.0, C(0, 0, 0, 0), 1.0, C(150, 0, 0, 0));
                        // face : arrondi + reflets (plus marques pour les metaux)
                        Brush faceShade = Grad(new Point(0, 0), new Point(0, 1),
                            0.00, C(A(70 + 150 * sh), 255, 250, 238),
                            0.14, C(A(20 + 60 * sh), 255, 255, 255),
                            0.38, C(0, 0, 0, 0),
                            0.52, C(A(90 * sh), 0, 0, 0),
                            0.70, C(A(70 * sh), 255, 255, 255),
                            1.00, C(A(110 + 20 * sh), 20, 10, 4));
                        Pen edgePen = new Pen(new SolidColorBrush(C(170, 15, 10, 5)), fontSize * 0.008);
                        Pen darkPen = new Pen(new SolidColorBrush(C(150, 30, 18, 8)), fontSize * 0.01);
                        Pen rimPen = new Pen(Grad(new Point(0, 0), new Point(0, 1),
                            0.0, C(A(170 + 80 * sh), 255, 245, 225), 0.5, C(A(30 + 40 * sh), 255, 250, 235), 1.0, C(0, 0, 0, 0)), fontSize * 0.012);
                        rimPen.LineJoin = PenLineJoin.Round; darkPen.LineJoin = PenLineJoin.Round;

                        DrawingVisual dv = new DrawingVisual();
                        using (DrawingContext dc = dv.RenderOpen())
                        {
                            dc.PushTransform(new TranslateTransform(-b.X + margin, -b.Y + margin));
                            dc.DrawGeometry(Tile(m.SideTex, b, rnd), null, side);
                            dc.DrawGeometry(sideShade, edgePen, side);
                            dc.DrawGeometry(Tile(m.FaceTex, b, rnd), null, face);
                            dc.DrawGeometry(faceShade, darkPen, face);
                            dc.DrawGeometry(null, rimPen, face);
                            dc.Pop();
                        }
                        DropShadowEffect shadow = new DropShadowEffect();
                        shadow.Color = Colors.Black; shadow.Direction = 295; shadow.Opacity = 0.5;
                        shadow.ShadowDepth = fontSize * 0.07; shadow.BlurRadius = fontSize * 0.16;
                        dv.Effect = shadow;
                        ContainerVisual host = new ContainerVisual();
                        host.Children.Add(dv);

                        RenderTargetBitmap rtb = new RenderTargetBitmap((int)Math.Ceiling(gl.W * rs), (int)Math.Ceiling(gl.H * rs), 96 * rs, 96 * rs, PixelFormats.Pbgra32);
                        rtb.Render(host);
                        rtb.Freeze();
                        gl.Bmps[mi] = rtb;
                    }
                    cache[c] = gl;
                }
            }

            if (gl != null)
            {
                Grid grid = new Grid();
                grid.Width = gl.W; grid.Height = gl.H;
                Image[] imgs = new Image[nMats];
                for (int mi = 0; mi < nMats; mi++)
                {
                    Image img = new Image();
                    img.Source = gl.Bmps[mi]; img.Width = gl.W; img.Height = gl.H; img.Stretch = Stretch.Fill;
                    img.Visibility = Visibility.Hidden;
                    imgs[mi] = img;
                    grid.Children.Add(img);
                }
                // voile sombre pour les lettres "au fond"
                Rectangle dark = new Rectangle();
                dark.Width = gl.W; dark.Height = gl.H; dark.Fill = Brushes.Black;
                dark.OpacityMask = new ImageBrush(gl.Bmps[0]); dark.Opacity = 0;
                Panel.SetZIndex(dark, 10);
                grid.Children.Add(dark);

                grid.RenderTransformOrigin = new Point(0.5, 0.5);
                ScaleTransform st = new ScaleTransform(1, 1);
                SkewTransform sk = new SkewTransform(0, 0);
                TranslateTransform tt = new TranslateTransform(0, 0);
                TransformGroup tg = new TransformGroup();
                tg.Children.Add(st); tg.Children.Add(sk); tg.Children.Add(tt);
                grid.RenderTransform = tg;

                Canvas.SetLeft(grid, padX + cursor + gl.Bounds.X - margin);
                Canvas.SetTop(grid, padY + gl.Bounds.Y - margin);
                canvas.Children.Add(grid);

                Letter L = new Letter();
                L.El = grid; L.S = st; L.K = sk; L.T = tt; L.Dark = dark; L.Imgs = imgs; L.Index = idx;
                letters.Add(L);
            }
            cursor += adv;
            idx++;
        }

        double cw = padX * 2 + total + ddx, chh = padY * 2 + lineH + ddy;
        canvas.Width = cw; canvas.Height = chh;

        win = new Window();
        win.WindowStyle = WindowStyle.None;
        win.AllowsTransparency = true;
        win.Background = Brushes.Transparent;
        win.Topmost = true;
        win.ShowInTaskbar = false;
        win.ShowActivated = false;
        win.ResizeMode = ResizeMode.NoResize;
        win.WindowStartupLocation = WindowStartupLocation.Manual;
        win.Left = -30000; win.Top = -30000;
        win.Width = cw; win.Height = chh;
        win.Content = canvas;

        vx = speed * 50; vy = speed * 38;
        endT = minutes * 60;

        win.SourceInitialized += delegate
        {
            hwnd = new WindowInteropHelper(win).Handle;
            int ex = GetWindowLong(hwnd, -20);
            SetWindowLong(hwnd, -20, ex | 0x20 | 0x80 | 0x08000000);   // TRANSPARENT | TOOLWINDOW | NOACTIVATE
        };
        win.Loaded += delegate
        {
            RECT r; GetWindowRect(hwnd, out r);
            pw = r.R - r.L; ph = r.B - r.T;
            System.Drawing.Rectangle p = System.Windows.Forms.Screen.PrimaryScreen.Bounds;
            px = p.X + (p.Width - pw) / 2.0; py = p.Y + (p.Height - ph) / 2.0;
            SetWindowPos(hwnd, new IntPtr(-1), (int)px, (int)py, 0, 0, 0x0001 | 0x0010);
            sw = Stopwatch.StartNew();
            CompositionTarget.Rendering += OnFrame;
        };

        BannerInit(msgs);
        win.ShowDialog();
    }

    static void OnFrame(object s, EventArgs e)
    {
        double t = sw.Elapsed.TotalSeconds;
        if (t - lastFrame < 0.022) return;          // ~45 images/s
        lastFrame = t;
        double dt = Math.Min(0.1, t - lastT); lastT = t;

        if (t > endT) { CompositionTarget.Rendering -= OnFrame; win.Close(); return; }

        BannerTick(t);

        double phase = t * 1.4;
        foreach (Letter L in letters)
        {
            // Vague de profondeur
            double a = phase - L.Index * 0.42;
            double z = Math.Sin(a);                  // -1 = au fond, +1 = devant
            double turn = Math.Cos(a);
            double sc = 1 + 0.17 * z;
            L.S.ScaleX = sc * (0.96 + 0.04 * Math.Abs(z));
            L.S.ScaleY = sc;
            L.K.AngleY = turn * 4.5;
            L.T.Y = z * amp * 0.45 + Math.Sin(phase * 0.55 - L.Index * 0.22) * amp * 0.35;
            L.Dark.Opacity = (1 - z) * 0.5 * 0.5;
            int zi = (int)(z * 1000);
            if (zi != L.Z) { Panel.SetZIndex(L.El, zi); L.Z = zi; }

            // Changement de matiere, propage de lettre en lettre
            double m = t / matPeriod - L.Index * 0.06;
            double fl = Math.Floor(m), f = m - fl;
            int cur = (((int)fl % nMats) + nMats) % nMats;
            int nxt = (cur + 1) % nMats;
            double fade = Clamp01((f - 0.55) / 0.45);
            fade = fade * fade * (3 - 2 * fade);
            if (cur != L.Cur || nxt != L.Nxt)
            {
                for (int j = 0; j < nMats; j++)
                    L.Imgs[j].Visibility = (j == cur || j == nxt) ? Visibility.Visible : Visibility.Hidden;
                Panel.SetZIndex(L.Imgs[cur], 1);
                Panel.SetZIndex(L.Imgs[nxt], 2);
                L.Imgs[cur].Opacity = 1;
                L.Cur = cur; L.Nxt = nxt;
            }
            L.Imgs[nxt].Opacity = fade;
        }

        // Deplacement + rebond sur l'ensemble des ecrans
        double nx = px + vx * dt;
        if (Inside(nx, py)) px = nx; else vx = -vx;
        double ny = py + vy * dt;
        if (Inside(px, ny)) py = ny; else vy = -vy;
        SetWindowPos(hwnd, new IntPtr(-1), (int)px, (int)py, 0, 0, 0x0001 | 0x0010);
    }
}
'@

$names = 'System','PresentationFramework','PresentationCore','WindowsBase','System.Xaml','System.Windows.Forms','System.Drawing'
$refs  = [AppDomain]::CurrentDomain.GetAssemblies() |
         Where-Object { $names -contains $_.GetName().Name } |
         ForEach-Object { $_.Location }

Add-Type -TypeDefinition $code -ReferencedAssemblies $refs -IgnoreWarnings

[NiahLog]::Run($Text, $Size, $Speed, $Wave, $Minutes, $MatSeconds, $Font, [string[]]$Messages)
