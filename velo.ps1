# ============================================================
#  VELOS DE COURSE qui se baladent sur tous les ecrans
#  - 3 velos au depart (parametre -Bikes), roues et pedalier qui tournent
#  - CLIC sur un velo => un nouveau velo arrive par le bord d'un ecran
#  - couleurs realistes aleatoires (cadre, guidon, selle, jantes...), pneus noirs
#  - les velos font demi-tour aux bords et passent d'un ecran a l'autre
#  - le Gestionnaire des taches reste accessible (Ctrl+Maj+Echap -> powershell.exe)
#  - s'arrete tout seul apres -Minutes minutes (15 par defaut)
#  Usage : powershell -ExecutionPolicy Bypass -File velo.ps1 [-Bikes 3] [-Minutes 30] [-Size 1.9] [-Speed 3] [-MaxBikes 25]
# ============================================================
param(
    [int]$Bikes      = 3,      # nombre de velos au depart
    [int]$Minutes    = 15,
    [double]$Size    = 1.9,    # taille des velos (1.9 = environ 330 px de long)
    [double]$Speed   = 3,      # vitesse (1 = balade, 3 = normal, 6 = sprint)
    [int]$MaxBikes   = 25,     # limite de securite pour les clics
    # Phrases affichees en haut de chaque ecran (le texte entre *etoiles* est mis en valeur)
    [string[]]$Messages = @(
        "Petit rappel : un PC non verrouillé, c'est une piste cyclable. *Windows + L* avant la pause !",
        "Pendant ta pause café, des cyclistes ont squatté ton écran. Avec *Windows + L*, ils restent au garage.",
        "Astuce sécurité du jour : *Windows + L*. Deux touches, zéro vélo.",
        "Session ouverte = porte ouverte. La prochaine fois : *Windows + L* !",
        "Le Tour de France passe par ton bureau... parce que tu n'as pas fait *Windows + L*."
    )
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms, System.Drawing

$code = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Shapes;

public static class Velo
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

    class Bike
    {
        public Window W;
        public IntPtr H;
        public RotateTransform R1, R2, Crank;
        public MatrixTransform MT;
        public double S, X, Y, VX, VY, Ang, NextTurn;
        public int PW, PH, Dir = 1;
        public bool Ready, AtEdge;
    }

    // Repere du velo (unites ~ 1 cm) : axe arriere (0,0), axe avant (98,0), sol y = 34
    const double UW = 178, UH = 98, OX = 40, OY = 58;

    static List<Bike> bikes = new List<Bike>();
    static Random rnd = new Random();
    static System.Drawing.Rectangle[] screens;
    static Application app;
    static Stopwatch sw;
    static double endT, lastT, lastFrame, baseSize, baseSpeed;
    static int maxBikes;

    // ---------- couleurs realistes ----------
    static Color C(int r, int g, int b) { return Color.FromArgb(255, (byte)r, (byte)g, (byte)b); }
    static Color C(int a, int r, int g, int b) { return Color.FromArgb((byte)a, (byte)r, (byte)g, (byte)b); }
    static Color[] frames = {
        C(190, 22, 30),   // rouge course
        C(24, 24, 27),    // noir
        C(236, 236, 232), // blanc
        C(120, 200, 188), // vert celeste
        C(22, 40, 92),    // bleu marine
        C(236, 192, 22),  // jaune
        C(230, 96, 22),   // orange
        C(178, 184, 190), // alu brosse
        C(18, 72, 46),    // vert anglais
        C(86, 90, 96),    // gris mat
        C(84, 40, 122),   // violet
        C(36, 118, 200)   // bleu ciel
    };
    static Color Pick(Color[] arr) { return arr[rnd.Next(arr.Length)]; }
    static SolidColorBrush Br(Color c) { return new SolidColorBrush(c); }
    static bool IsDark(Color c) { return c.R * 0.3 + c.G * 0.59 + c.B * 0.11 < 70; }

    // ---------- primitives ----------
    static Line Ln(Canvas c, double x1, double y1, double x2, double y2, double th, Brush b)
    {
        Line l = new Line();
        l.X1 = x1; l.Y1 = y1; l.X2 = x2; l.Y2 = y2;
        l.StrokeThickness = th; l.Stroke = b;
        l.StrokeStartLineCap = PenLineCap.Round; l.StrokeEndLineCap = PenLineCap.Round;
        c.Children.Add(l);
        return l;
    }
    static Ellipse Circle(Canvas c, double cx, double cy, double r, Brush fill, Brush stroke, double th)
    {
        Ellipse e = new Ellipse();
        e.Width = 2 * r; e.Height = 2 * r;
        e.Fill = fill; e.Stroke = stroke; e.StrokeThickness = th;
        Canvas.SetLeft(e, cx - r); Canvas.SetTop(e, cy - r);
        c.Children.Add(e);
        return e;
    }
    // Tube de cadre : couleur + reflet brillant au-dessus + ombre en dessous
    static void Tube(Canvas c, double x1, double y1, double x2, double y2, double th, Color col)
    {
        Ln(c, x1, y1, x2, y2, th, Br(col));
        double dx = x2 - x1, dy = y2 - y1, L = Math.Sqrt(dx * dx + dy * dy);
        double nx = dy / L, ny = -dx / L;
        if (ny > 0 || (Math.Abs(ny) < 0.2 && nx > 0)) { nx = -nx; ny = -ny; }
        int hi = IsDark(col) ? 55 : 95;
        Ln(c, x1 + nx * th * 0.22, y1 + ny * th * 0.22, x2 + nx * th * 0.22, y2 + ny * th * 0.22, th * 0.28, Br(C(hi, 255, 255, 255)));
        Ln(c, x1 - nx * th * 0.32, y1 - ny * th * 0.32, x2 - nx * th * 0.32, y2 - ny * th * 0.32, th * 0.22, Br(C(60, 0, 0, 0)));
    }
    static PathGeometry PG(double x0, double y0, params PathSegment[] segs)
    {
        PathFigure f = new PathFigure();
        f.StartPoint = new Point(x0, y0);
        foreach (PathSegment s in segs) f.Segments.Add(s);
        PathGeometry g = new PathGeometry();
        g.Figures.Add(f);
        return g;
    }
    static BezierSegment Bz(double x1, double y1, double x2, double y2, double x3, double y3)
    {
        return new BezierSegment(new Point(x1, y1), new Point(x2, y2), new Point(x3, y3), true);
    }
    static LineSegment LS(double x, double y) { return new LineSegment(new Point(x, y), true); }
    static Path Stroke(Canvas c, Geometry g, double th, Brush b)
    {
        Path p = new Path();
        p.Data = g; p.StrokeThickness = th; p.Stroke = b;
        p.StrokeStartLineCap = PenLineCap.Round; p.StrokeEndLineCap = PenLineCap.Round; p.StrokeLineJoin = PenLineJoin.Round;
        c.Children.Add(p);
        return p;
    }
    static Path Arc(Canvas c, double r, double a0, double a1, double th, Brush b)
    {
        Point p0 = new Point(r * Math.Cos(a0), r * Math.Sin(a0));
        Point p1 = new Point(r * Math.Cos(a1), r * Math.Sin(a1));
        PathGeometry g = PG(p0.X, p0.Y, new ArcSegment(p1, new Size(r, r), 0, false, SweepDirection.Clockwise, true));
        Path p = Stroke(c, g, th, b);
        p.StrokeStartLineCap = PenLineCap.Flat; p.StrokeEndLineCap = PenLineCap.Flat;
        return p;
    }

    // ---------- roue ----------
    static Canvas Wheel(double cx, double cy, bool carbon, Color decal, out RotateTransform rt)
    {
        Canvas w = new Canvas();
        Canvas.SetLeft(w, cx); Canvas.SetTop(w, cy);
        Circle(w, 0, 0, 34, Br(C(2, 0, 0, 0)), null, 0);          // zone cliquable (quasi invisible)

        Canvas rot = new Canvas();
        rt = new RotateTransform(rnd.Next(360));
        rot.RenderTransform = rt;
        double depth = carbon ? 5.2 : 1.8;
        double rimIn = 30.9 - depth;
        Brush spoke = Br(C(185, 190, 196));
        int n = carbon ? 18 : 24;
        for (int i = 0; i < n; i++)
        {
            double a = i * 2 * Math.PI / n;
            double off = (i % 2 == 0) ? 0.14 : -0.14;               // rayonnage croise
            Ln(rot, 2.4 * Math.Cos(a), 2.4 * Math.Sin(a), rimIn * Math.Cos(a + off), rimIn * Math.Sin(a + off), 0.32, spoke);
        }
        Brush rimB = carbon ? Br(C(28, 28, 30)) : Br(C(196, 200, 205));
        Circle(rot, 0, 0, 30.9 - depth / 2, null, rimB, depth);
        if (carbon)
        {
            Brush d = Br(decal);
            Arc(rot, 30.9 - depth / 2, 0.15, 0.85, depth * 0.45, d);
            Arc(rot, 30.9 - depth / 2, Math.PI + 0.15, Math.PI + 0.85, depth * 0.45, d);
        }
        else
        {
            Circle(rot, 0, 0, 30.9 - depth, null, Br(C(120, 125, 130)), 0.3);
        }
        Ln(rot, 0, -(30.9 - depth), 0, -(30.9 - depth) + 2.2, 0.8, Br(C(170, 170, 175)));   // valve
        Circle(rot, 0, 0, 2.6, Br(C(200, 204, 208)), Br(C(90, 90, 95)), 0.4);              // moyeu
        w.Children.Add(rot);

        // pneu noir
        Circle(w, 0, 0, 32.5, null, Br(C(18, 18, 18)), 3.2);
        Circle(w, 0, 0, 33.8, null, Br(C(60, 255, 255, 255)), 0.25);
        Circle(w, 0, 0, 31.3, null, Br(C(40, 40, 42)), 0.4);
        return w;
    }

    // ---------- velo complet ----------
    static Canvas BuildBike(Bike bk)
    {
        Color frame = Pick(frames);
        Color accent = IsDark(frame) ? Pick(new Color[] { C(236, 236, 232), C(200, 30, 36), C(240, 200, 30), C(120, 200, 188) })
                                     : Pick(new Color[] { C(24, 24, 27), C(236, 236, 232) });
        Color tape = Pick(new Color[] { C(24, 24, 27), C(24, 24, 27), C(238, 238, 235), frame, accent });
        Color saddle = rnd.NextDouble() < 0.7 ? C(26, 26, 28) : C(236, 236, 232);
        Color parts = rnd.NextDouble() < 0.6 ? C(30, 30, 32) : C(190, 194, 200);      // potence, tige de selle
        Color group = rnd.NextDouble() < 0.5 ? C(45, 45, 48) : C(196, 200, 206);      // pedalier
        bool carbon = rnd.NextDouble() < 0.6;
        Color decal = rnd.NextDouble() < 0.5 ? C(236, 236, 232) : accent;

        Canvas c = new Canvas();

        // ombre au sol
        Ellipse sh = new Ellipse();
        sh.Width = 160; sh.Height = 7;
        sh.Fill = new RadialGradientBrush(C(110, 0, 0, 0), C(0, 0, 0, 0));
        Canvas.SetLeft(sh, 49 - 80); Canvas.SetTop(sh, 34.6 - 3.5);
        c.Children.Add(sh);

        // zone cliquable quasi invisible sur toute la silhouette (sinon les clics
        // entre les rayons / dans le triangle du cadre traversent la fenetre)
        Rectangle hit = new Rectangle();
        hit.Width = 172; hit.Height = 94; hit.RadiusX = 22; hit.RadiusY = 22;
        hit.Fill = Br(C(3, 0, 0, 0));
        Canvas.SetLeft(hit, -37); Canvas.SetTop(hit, -57);
        c.Children.Add(hit);

        // roues
        c.Children.Add(Wheel(0, 0, carbon, decal, out bk.R1));
        c.Children.Add(Wheel(98, 0, carbon, decal, out bk.R2));

        bk.Crank = new RotateTransform(rnd.Next(360));

        // manivelle cote oppose (derriere le cadre)
        Canvas farCrank = new Canvas();
        Canvas.SetLeft(farCrank, 41); Canvas.SetTop(farCrank, 7);
        farCrank.RenderTransform = bk.Crank;
        Ln(farCrank, 0, 0, 0, -17, 2.2, Br(C(70, 70, 74)));
        Rectangle fp = new Rectangle(); fp.Width = 6; fp.Height = 1.8; fp.Fill = Br(C(40, 40, 42));
        Canvas.SetLeft(fp, -3); Canvas.SetTop(fp, -17.9); farCrank.Children.Add(fp);
        c.Children.Add(farCrank);

        // cadre (geometrie route)
        double bbx = 41, bby = 7;
        Tube(c, 0, 0, bbx, bby, 2.1, frame);                 // bases
        Tube(c, 0, 0, 27.6, -38.5, 1.7, frame);              // haubans
        Tube(c, bbx, bby, 26.4, -42.5, 3.1, frame);          // tube de selle
        Tube(c, bbx, bby, 86.8, -37.5, 3.8, frame);          // tube diagonal
        Tube(c, 27.3, -39.5, 84.3, -46.2, 2.9, frame);       // tube horizontal
        Tube(c, 87.6, -34.8, 83.6, -48.6, 4.3, frame);       // douille de direction
        // bande deco sur le diagonal
        Ln(c, bbx + (86.8 - bbx) * 0.38, bby + (-37.5 - bby) * 0.38, bbx + (86.8 - bbx) * 0.72, bby + (-37.5 - bby) * 0.72, 1.1, Br(accent));

        // fourche
        PathGeometry fork = PG(87.6, -34.8, Bz(90, -24, 94.6, -10, 98, 0));
        Stroke(c, fork, 2.6, Br(frame));
        Path fh = Stroke(c, fork, 0.7, Br(C(IsDark(frame) ? 55 : 95, 255, 255, 255)));
        fh.RenderTransform = new TranslateTransform(-0.6, -0.2);

        // bidon (1 chance sur 2)
        if (rnd.NextDouble() < 0.5)
        {
            Color bottle = Pick(new Color[] { C(238, 238, 235), C(200, 30, 36), C(30, 30, 32), C(60, 150, 220), C(240, 200, 30) });
            Rectangle bt = new Rectangle();
            bt.Width = 19; bt.Height = 6.2; bt.RadiusX = 2.2; bt.RadiusY = 2.2;
            bt.Fill = new LinearGradientBrush(bottle, Color.FromArgb(255, (byte)(bottle.R * 0.7), (byte)(bottle.G * 0.7), (byte)(bottle.B * 0.7)), 90);
            double ang = Math.Atan2(-37.5 - bby, 86.8 - bbx) * 180 / Math.PI;
            double tx = bbx + (86.8 - bbx) * 0.5 + 3.4 * Math.Sin(ang * Math.PI / 180);
            double ty = bby + (-37.5 - bby) * 0.5 - 3.4 * Math.Cos(ang * Math.PI / 180);
            TransformGroup tg = new TransformGroup();
            tg.Children.Add(new TranslateTransform(-9.5, -3.1));
            tg.Children.Add(new RotateTransform(ang));
            tg.Children.Add(new TranslateTransform(tx, ty));
            bt.RenderTransform = tg;
            c.Children.Add(bt);
        }

        // tige de selle + selle
        Ln(c, 26.4, -42.5, 24.6, -49.6, 2.1, Br(parts));
        Path sad = new Path();
        PathGeometry sg = PG(12.5, -52.6, Bz(16, -54.8, 25, -54.0, 36.5, -52.3), LS(36.5, -51.2), Bz(28, -50.5, 20, -50.1, 13.5, -49.9));
        sg.Figures[0].IsClosed = true;
        sad.Data = sg; sad.Fill = Br(saddle); sad.Stroke = Br(C(60, 0, 0, 0)); sad.StrokeThickness = 0.3;
        c.Children.Add(sad);
        Ln(c, 20, -50.6, 30, -50.9, 0.6, Br(C(110, 110, 115)));     // rails

        // direction : entretoises, potence, cintre route
        Ln(c, 83.6, -48.6, 83.0, -51.0, 3.2, Br(C(28, 28, 30)));
        Ln(c, 83.1, -50.4, 93.4, -51.8, 2.5, Br(parts));
        PathGeometry bar = PG(93.4, -51.8, LS(99, -51.4), Bz(103.2, -51.2, 104.4, -46.5, 103.4, -41.5), Bz(102.6, -37.4, 100.2, -35.6, 96.6, -36.2));
        Stroke(c, bar, 2.3, Br(tape));
        // cocottes + leviers
        Ellipse hood = new Ellipse(); hood.Width = 4.6; hood.Height = 2.8; hood.Fill = Br(C(30, 30, 32));
        Canvas.SetLeft(hood, 98.4); Canvas.SetTop(hood, -53.4); c.Children.Add(hood);
        Stroke(c, PG(100.6, -51, Bz(102.4, -48.2, 102.2, -43.6, 100.6, -40.6)), 1.3, Br(group));

        // cassette + derailleur + chaine (cote transmission)
        Circle(c, 0, 0, 5.2, Br(C(95, 95, 100)), Br(C(150, 150, 155)), 0.8);
        Stroke(c, PG(0.5, 1.5, LS(2.2, 7.2), LS(-0.8, 10.4)), 1.3, Br(C(40, 40, 42)));
        Circle(c, 2.2, 7.2, 1.2, Br(C(60, 60, 64)), null, 0);
        Circle(c, -0.8, 10.4, 1.2, Br(C(60, 60, 64)), null, 0);
        Brush chain = Br(C(105, 105, 110));
        Ln(c, bbx, bby - 10.6, 0, -5.2, 0.9, chain);
        Ln(c, bbx, bby + 10.6, -0.8, 11.6, 0.9, chain);

        // plateau
        Circle(c, bbx, bby, 10.6, null, Br(C(70, 70, 74)), 1.4);
        Circle(c, bbx, bby, 9.6, null, Br(group), 0.8);

        // manivelle avant + araignee (tourne)
        Canvas nearCrank = new Canvas();
        Canvas.SetLeft(nearCrank, bbx); Canvas.SetTop(nearCrank, bby);
        nearCrank.RenderTransform = bk.Crank;
        for (int i = 0; i < 4; i++)
        {
            double a = i * Math.PI / 2 + Math.PI / 4;
            Ln(nearCrank, 0, 0, 9 * Math.Cos(a), 9 * Math.Sin(a), 1.2, Br(group));
        }
        Ln(nearCrank, 0, 0, 0, 17, 2.4, Br(group));
        Circle(nearCrank, 0, 0, 2.2, Br(C(160, 160, 165)), Br(C(70, 70, 74)), 0.4);
        Rectangle np = new Rectangle(); np.Width = 7; np.Height = 2; np.Fill = Br(C(26, 26, 28)); np.RadiusX = 0.6; np.RadiusY = 0.6;
        Canvas.SetLeft(np, -3.5); Canvas.SetTop(np, 16); nearCrank.Children.Add(np);
        c.Children.Add(nearCrank);

        return c;
    }

    static void SetDir(Bike b)
    {
        double s = b.S, m = b.Dir;
        b.MT.Matrix = new Matrix(s * m, 0, 0, s, m > 0 ? s * OX : UW * s - s * OX, s * OY);
    }

    static bool Inside(double x, double y, int pw, int ph)
    {
        int x0 = (int)x, y0 = (int)y, x1 = x0 + pw - 1, y1 = y0 + ph - 1;
        return InAny(x0, y0) && InAny(x1, y0) && InAny(x0, y1) && InAny(x1, y1);
    }
    static bool InAny(int x, int y)
    {
        foreach (System.Drawing.Rectangle r in screens) if (r.Contains(x, y)) return true;
        return false;
    }

    static void Spawn(bool atEdge)
    {
        Bike b = new Bike();
        b.S = baseSize * (0.88 + rnd.NextDouble() * 0.24);
        b.Dir = rnd.Next(2) == 0 ? 1 : -1;
        b.VX = b.Dir * baseSpeed * (24 + rnd.NextDouble() * 20);
        b.VY = (rnd.NextDouble() - 0.5) * 24;
        b.AtEdge = atEdge;

        Canvas bikeCanvas = BuildBike(b);
        b.MT = new MatrixTransform();
        bikeCanvas.RenderTransform = b.MT;
        SetDir(b);

        Canvas root = new Canvas();
        root.Width = UW * b.S; root.Height = UH * b.S;
        root.Children.Add(bikeCanvas);
        root.Cursor = Cursors.Hand;

        Window w = new Window();
        w.WindowStyle = WindowStyle.None;
        w.AllowsTransparency = true;
        w.Background = Brushes.Transparent;
        w.Topmost = true;
        w.ShowInTaskbar = false;
        w.ShowActivated = false;
        w.ResizeMode = ResizeMode.NoResize;
        w.WindowStartupLocation = WindowStartupLocation.Manual;
        w.Left = -30000; w.Top = -30000;
        w.Width = root.Width; w.Height = root.Height;
        w.Content = root;
        b.W = w;

        w.SourceInitialized += delegate
        {
            b.H = new WindowInteropHelper(w).Handle;
            int ex = GetWindowLong(b.H, -20);
            SetWindowLong(b.H, -20, ex | 0x80 | 0x08000000);       // TOOLWINDOW | NOACTIVATE (cliquable)
        };
        w.Loaded += delegate
        {
            RECT r; GetWindowRect(b.H, out r);
            b.PW = r.R - r.L; b.PH = r.B - r.T;
            for (int tries = 0; tries < 60; tries++)
            {
                System.Drawing.Rectangle s = screens[rnd.Next(screens.Length)];
                double x = b.AtEdge ? (b.Dir > 0 ? s.X + 1 : s.Right - b.PW - 1)
                                    : s.X + rnd.NextDouble() * Math.Max(1, s.Width - b.PW);
                double y = s.Y + rnd.NextDouble() * Math.Max(1, s.Height - b.PH);
                b.X = x; b.Y = y;
                if (Inside(x, y, b.PW, b.PH)) break;
            }
            SetWindowPos(b.H, new IntPtr(-1), (int)b.X, (int)b.Y, 0, 0, 0x0001 | 0x0010);
            b.NextTurn = sw.Elapsed.TotalSeconds + 2 + rnd.NextDouble() * 4;
            b.Ready = true;
        };
        w.MouseLeftButtonDown += delegate
        {
            if (bikes.Count < maxBikes) Spawn(true);
        };

        bikes.Add(b);
        w.Show();
    }

    public static void Run(int count, double minutes, double size, double speed, int maxB, string[] msgs)
    {
        try { SetProcessDPIAware(); } catch { }
        System.Windows.Forms.Screen[] all = System.Windows.Forms.Screen.AllScreens;
        screens = new System.Drawing.Rectangle[all.Length];
        for (int i = 0; i < all.Length; i++) screens[i] = all[i].WorkingArea;   // evite la barre des taches

        baseSize = size; baseSpeed = speed; maxBikes = maxB;
        endT = minutes * 60;

        app = new Application();
        app.ShutdownMode = ShutdownMode.OnExplicitShutdown;
        sw = Stopwatch.StartNew();
        BannerInit(msgs);
        for (int i = 0; i < count; i++) Spawn(false);
        CompositionTarget.Rendering += OnFrame;
        app.Run();
    }

    static void OnFrame(object s, EventArgs e)
    {
        double t = sw.Elapsed.TotalSeconds;
        if (t - lastFrame < 0.022) return;          // ~45 images/s
        lastFrame = t;
        double dt = Math.Min(0.1, t - lastT); lastT = t;

        if (t > endT) { CompositionTarget.Rendering -= OnFrame; app.Shutdown(); return; }

        BannerTick(t);

        foreach (Bike b in bikes)
        {
            if (!b.Ready) continue;

            if (t > b.NextTurn)
            {
                b.VY = (rnd.NextDouble() - 0.5) * 30;
                b.NextTurn = t + 2 + rnd.NextDouble() * 5;
            }

            double nx = b.X + b.VX * dt;
            if (Inside(nx, b.Y, b.PW, b.PH)) b.X = nx;
            else { b.VX = -b.VX; b.Dir = b.VX > 0 ? 1 : -1; SetDir(b); }

            double ny = b.Y + b.VY * dt;
            if (Inside(b.X, ny, b.PW, b.PH)) b.Y = ny; else b.VY = -b.VY;

            // roues : rotation = distance / rayon (34 unites)
            double pxPerUnit = b.PW / UW;
            b.Ang += Math.Abs(b.VX) * dt / (34 * pxPerUnit) * 180 / Math.PI;
            b.R1.Angle = b.Ang;
            b.R2.Angle = b.Ang + 37;
            b.Crank.Angle = b.Ang / 2.9;              // braquet ~ 50x17

            SetWindowPos(b.H, new IntPtr(-1), (int)b.X, (int)b.Y, 0, 0, 0x0001 | 0x0010);
        }
    }
}
'@

$names = 'System','PresentationFramework','PresentationCore','WindowsBase','System.Xaml','System.Windows.Forms','System.Drawing'
$refs  = [AppDomain]::CurrentDomain.GetAssemblies() |
         Where-Object { $names -contains $_.GetName().Name } |
         ForEach-Object { $_.Location }

Add-Type -TypeDefinition $code -ReferencedAssemblies $refs -IgnoreWarnings

[Velo]::Run($Bikes, $Minutes, $Size, $Speed, $MaxBikes, [string[]]$Messages)
