#requires -Version 3

<#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
#>

Set-StrictMode -Version 2.0

$xaml = @'
<Window
   xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
   xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
   Width="525"
   Height="350"
   ResizeMode="NoResize"
   Title="Create Screensaver">
   <Grid>
      <Label
         Name="lblImageFolder"
         Width="400"
         HorizontalAlignment="Left"
         Margin="10,20,0,0"
         VerticalAlignment="Top"
         Content="Image Folder"/>
      <TextBox
         Name="txtImageFolder"
         Width="400"
         Height="25"
         HorizontalAlignment="Left"
         Margin="20,45,0,0"
         VerticalAlignment="Top"
         Text="" />
      <Button
         Name="btnBrowseForImages"
         Width="75"
         Height="25"
         HorizontalAlignment="Left"
         Margin="425,45,0,0"
         VerticalAlignment="Top"
         Content="Browse"/>
      <Label
         Name="lblOutputFile"
         Width="400"
         HorizontalAlignment="Left"
         Margin="10,80,0,0"
         VerticalAlignment="Top"
         Content="Screensaver File" />
      <TextBox
         Name="txtOutputFile"
         Width="400"
         Height="25"
         HorizontalAlignment="Left"
         Margin="20,105,0,0"
         VerticalAlignment="Top"
         Text="" />
      <Button
         Name="btnBrowseForScreensaver"
         Width="75"
         Height="25"
         HorizontalAlignment="Left"
         Margin="425,105,0,0"
         VerticalAlignment="Top"
         Content="Browse"/>
      <Label
         Name="lblSlideTimeout"
         HorizontalAlignment="Left"
         Margin="10,140,0,0"
         VerticalAlignment="Top"
         Content="Slide Timeout" />
      <TextBox
         Name="txtSlideTimeout"
         Width="80"
         Height="25"
         HorizontalAlignment="Left"
         Margin="20,165,0,0"
         VerticalAlignment="Top"
         Text="10"
         TextWrapping="Wrap"/>
      <Label
         Name="lblSeconds"
         Width="300"
         Height="25"
         HorizontalAlignment="Left"
         Margin="100,165,0,0"
         VerticalAlignment="Top"
         Content="Seconds" />
     <Label 
        Name="lblMessage"
        HorizontalAlignment="Left"
        Margin="20,200,0,0"
        VerticalAlignment="Top"
        Content=""
        FontSize="22"
        Foreground="#FFFF0700" />
     <Button
         Name="btnRun"
         Width="75"
         Height="25"
         HorizontalAlignment="Left"
         Margin="340,275,0,0"
         VerticalAlignment="Top"
         Content="Run" 
         Visibility="Hidden" />
      <Button
         Name="btnBuild"
         Width="75"
         Height="25"
         HorizontalAlignment="Left"
         Margin="425,275,0,0"
         VerticalAlignment="Top"
         Content="Build"/>
   </Grid>
</Window>
'@

$source = @'
namespace SimpleScreensaver
{
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.Reflection;
    using System.Windows;
    using System.Windows.Controls;
    using System.Windows.Input;
    using System.Windows.Media;
    using System.Windows.Media.Animation;
    using System.Windows.Media.Imaging;
    using System.Windows.Threading;

    public class SimpleScreensaver : Window
    {
        private const int BaseDisplayTime = ###timeout###;
        private static readonly IList<BitmapImage> Images = new List<BitmapImage>();

        [STAThread]
        public static void Main(string[] args)
        {
            var arg1 = string.Empty;
            var arg2 = string.Empty;

            if (args.Length > 0)
            {
                var splitArgs = args[0].Split(':');
                arg1 = splitArgs[0].ToLower().Trim();

                if (splitArgs.Length > 1)
                {
                    // examples /p:1234 or /c:1234
                    arg2 = splitArgs[1].ToLower().Trim();
                }
                else if (args.Length > 1)
                {
                    // examples /p 1234 or / c 1234
                    arg2 = args[1].ToLower().Trim();
                }
            }

            switch (arg1)
            {
                case "/s":
                    // show screensaver
                    ShowScreensaver();
                    break;
                case "/p":
                    // show the preview window
                    // Not implemented
                    break;
                default:
                    // show config, covers the /c option too
                    // Not implemented
                    break;
            }
        }

        private static void ShowScreensaver()
        {
            // load images
            var slides = new[]
                             {
                                 ###images###
                             };

            foreach (var slide in slides)
            {
                using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(slide))
                {
                    if (stream == null)
                    {
                        continue;
                    }

                    var image = new BitmapImage();
                    var result = new byte[stream.Length];
                    stream.Read(result, 0, (int)stream.Length);
                    image.BeginInit();
                    image.StreamSource = new MemoryStream(result);
                    image.EndInit();
                    Images.Add(image);
                }
            }

            // start screensaver on each screen
            var app = new Application();
            var screenCount = 0;
            var random = new Random();
            foreach (var screen in System.Windows.Forms.Screen.AllScreens)
            {
                // set the display time to the base time + offset so multiple screens 
                // change images at different times
                // send the screen count so each screen has a different slide
                // it just looks nicer
                var window = new SimpleScreensaver(
                    screen.Bounds, screenCount, BaseDisplayTime + random.Next(BaseDisplayTime / 2));
                window.Show();
                ++screenCount;
            }

            app.Run();
        }

        /** 
         *    
         *  Screensaver
         *    
         **/

        private readonly Storyboard fadeOut;
        private readonly Storyboard fadeIn;
        private readonly Image slide;
        private int nextSlide;
        private bool mouseMoved;
        private Point mousePosition;

        private SimpleScreensaver(System.Drawing.Rectangle bounds, int startSlide, int displayTime)
        {
            //
            // Window setup
            //
            this.Title = "Simple Screensaver";
            this.Background = Brushes.Black;
            this.WindowStyle = WindowStyle.None;
            this.ResizeMode = ResizeMode.NoResize;
            this.WindowStartupLocation = WindowStartupLocation.Manual;
            this.Top = bounds.Top;
            this.Left = bounds.Left;
            this.Height = bounds.Height;
            this.Width = bounds.Width;
            this.Cursor = Cursors.None;
            this.Topmost = true;

            //
            // Set first slide
            //
            this.nextSlide = startSlide % Images.Count;

            //
            // Events 
            //
            this.KeyDown += this.Window_KeyDown;
            this.MouseDown += this.Window_MouseDown;
            this.MouseMove += this.Window_MouseMove;

            //
            // Add controls to window
            //
            this.slide = new Image
            {
                Name = "slide",
                Stretch = Stretch.Uniform,
                Margin = new Thickness(0),
            };

            var grid = new Grid();
            grid.Children.Add(this.slide);
            this.Content = grid;

            //
            // Setup fade in/fade out actions
            //
            var fadeInAnimation = new DoubleAnimation
            {
                From = 0,
                To = 1,
                Duration = new Duration(TimeSpan.FromSeconds(2))
            };
            Storyboard.SetTargetProperty(fadeInAnimation, new PropertyPath(OpacityProperty));
            this.fadeIn = new Storyboard();
            this.fadeIn.Children.Add(fadeInAnimation);

            var fadeOutAnimation = new DoubleAnimation
            {
                From = 1,
                To = 0,
                Duration = new Duration(TimeSpan.FromSeconds(2))
            };
            Storyboard.SetTargetProperty(fadeOutAnimation, new PropertyPath(OpacityProperty));
            this.fadeOut = new Storyboard();
            this.fadeOut.Children.Add(fadeOutAnimation);
            this.fadeOut.Completed += this.FadeOut_Completed;

            //
            // Setup timer
            //
            var timer = new DispatcherTimer();
            timer.Tick += this.Timer_Tick;
            timer.Interval = new TimeSpan(0, 0, displayTime);
            timer.Start();

            //
            // Trigger first image
            //
            this.FadeOut_Completed(null, EventArgs.Empty);
        }

        private void Window_KeyDown(object sender, KeyEventArgs e)
        {
            Application.Current.Shutdown();
        }

        private void Window_MouseDown(object sender, MouseButtonEventArgs e)
        {
            Application.Current.Shutdown();
        }

        private void Window_MouseMove(object sender, MouseEventArgs e)
        {
            var position = e.GetPosition(this);

            if (this.mouseMoved)
            {
                // only close out if the mouse moved enough
                if (Math.Abs(this.mousePosition.X - position.X) > 50 || Math.Abs(this.mousePosition.Y - position.Y) > 50)
                {
                    Application.Current.Shutdown();
                }
            }
            else
            {
                this.mouseMoved = true;
                this.mousePosition = position;
            }
        }

        private void FadeOut_Completed(object sender, EventArgs e)
        {
            this.slide.BeginInit();
            this.slide.Source = Images[this.nextSlide];
            this.slide.EndInit();

            this.nextSlide = (this.nextSlide + 1) % Images.Count;

            // fade in the new image
            this.fadeIn.Begin(this.slide);
        }

        private void Timer_Tick(object sender, EventArgs e)
        {
            // after fade out is complete it will 
            // trigger the event to switch to the next slide
            this.fadeOut.Begin(this.slide);
        }
    }
}
'@

function Convert-XAMLtoWindow
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $xaml,
        
        [string[]]
        $NamedElements,
        
        [switch]
        $PassThru
    )
    
    Add-Type -AssemblyName PresentationFramework
    
    $reader = [System.XML.XMLReader]::Create([System.IO.StringReader]$xaml)
    $result = [System.Windows.Markup.XAMLReader]::Load($reader)
    foreach($Name in $NamedElements)
    {
        $result | Add-Member -MemberType NoteProperty -Name $Name -Value $result.FindName($Name) -Force
    }
    
    if ($PassThru)
    {
        $result
    } else {
        $result.ShowDialog()
    }
}

function New-Screensaver 
{
    param()

    $provider = New-Object -TypeName Microsoft.CSharp.CSharpCodeProvider
    $provider = [Microsoft.CSharp.CSharpCodeProvider]::CreateProvider('CSharp')

    $cp = New-Object -TypeName System.CodeDom.Compiler.CompilerParameters
    $cp.GenerateExecutable = $true
    $cp.OutputAssembly = $window.txtOutputFile.Text
    $cp.IncludeDebugInformation = $false

    $cp.ReferencedAssemblies.Add('System.dll')
    $cp.ReferencedAssemblies.Add('System.Xaml.dll')
    $cp.ReferencedAssemblies.Add('System.Drawing.dll')
    $cp.ReferencedAssemblies.Add('System.Windows.Forms.dll')

    [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object -Process {
        if($_.FullName -match 'PresentationCore' -or
           $_.FullName -match 'PresentationFramework' -or
           $_.FullName -match 'WindowsBase' ) 
        {
            $cp.ReferencedAssemblies.Add($_.Location)
        }
    }
    
    $cp.GenerateInMemory = $false
    $cp.WarningLevel = 3
    $cp.TreatWarningsAsErrors = $false
    $cp.CompilerOptions = '/optimize /target:winexe'
    $cp.TempFiles = New-Object -TypeName System.CodeDom.Compiler.TempFileCollection -ArgumentList ($env:TEMP, $false)

    # Add images as resources 
    $resList = @()
    $folderProps = @{'Path' = (Join-Path -Path $window.txtImageFolder.Text -ChildPath '*');
                     'Include' = @('*.jpg','*.jpeg','*.bmp','*.gif','*.png')
                    }
    foreach($file in (Get-ChildItem @folderProps | Sort-Object -Property Name))
    {
        $cp.EmbeddedResources.Add($file.FullName.ToLower())
        $resList += '"{0}"' -f $file.Name.ToLower()
    }
    
    $srcFile = Join-Path -Path $env:TEMP -ChildPath 'screensaver.cs'
    $tmpSource = $source -replace '###timeout###', $window.txtSlideTimeout.Text
    $tmpSource = $tmpSource -replace '###images###', ($resList -join ',')
    $tmpSource | Out-File -FilePath $srcFile -Force

    $result = $provider.CompileAssemblyFromFile($cp, $srcFile)

    Remove-Item -Path $srcFile -Force -ErrorAction SilentlyContinue
    
    if($result.NativeCompilerReturnValue -eq 0)
    {
        $window.lblMessage.Content = 'Screensaver built successfully'
        $window.btnRun.Visibility = [System.Windows.Visibility]::Visible
    } else {
        $window.lblMessage.Content = 'Screensaver build failed'
    }
}

$window = Convert-XAMLtoWindow -XAML $xaml -NamedElements 'lblImageFolder', 'txtImageFolder', 'btnBrowseForImages', 
                                                          'lblOutputFile', 'txtOutputFile', 'btnBrowseForScreensaver', 
                                                          'lblSlideTimeout', 'txtSlideTimeout', 'lblSeconds', 
                                                          'lblMessage', 'btnRun', 'btnBuild' -PassThru

$window.btnBrowseForImages.add_Click(
    {
        [System.Object]$sender = $args[0]
        [System.Windows.RoutedEventArgs]$e = $args[1]

        $object = New-Object -ComObject Shell.Application
        $folder = $object.BrowseForFolder(0, 'Select folder that contains images', 0, 0)
        
        if($folder -ne $null)
        {
            $window.txtImageFolder.Text = $folder.self.Path
            $window.lblMessage.Content = ''
            $window.btnRun.Visibility = [System.Windows.Visibility]::Hidden
        }
    }
)

$window.btnBrowseForScreensaver.add_Click(
    {
        [System.Object]$sender = $args[0]
        [System.Windows.RoutedEventArgs]$e = $args[1]

        $saveAs = New-Object -TypeName Microsoft.Win32.SaveFileDialog
        $saveAs.DefaultExt = '.scr'
        $saveAs.Filter = 'Screensaver|*.scr'

        $result = $saveAs.ShowDialog()

        if($result -eq 'OK')
        {
            $window.txtOutputFile.Text = $saveAs.FileName
            $window.lblMessage.Content = ''
            $window.btnRun.Visibility = [System.Windows.Visibility]::Hidden
        }
    }
)

$window.btnRun.add_Click(
    {
        [System.Object]$sender = $args[0]
        [System.Windows.RoutedEventArgs]$e = $args[1]   
        
        if(Test-Path -Path $window.txtOutputFile.Text)
        {
            Start-Process -FilePath $window.txtOutputFile.Text -ArgumentList '/s'
        }
    }
)

$window.btnBuild.add_Click(
    {
        [System.Object]$sender = $args[0]
        [System.Windows.RoutedEventArgs]$e = $args[1]

        if($window.txtImageFolder.Text -eq '')
        {
            $window.lblMessage.Content = 'Image folder is not valid'
            return
        }

        if(-Not (Test-Path -Path $window.txtImageFolder.Text))
        {
            $window.lblMessage.Content = 'Image folder does not exist'
            return
        }

        if($window.txtOutputFile.Text -eq '')
        {
            $window.lblMessage.Content = 'Screensaver file is not valid'
            return
        }
        
        $x = 0
        $isNum = [System.Int32]::TryParse($window.txtSlideTimeout.Text, [ref]$x)
        
        if(-Not $isNum)
        { 
            $window.lblMessage.Content = 'Invalid time out'
            return
        }

        $window.txtSlideTimeout.Text = $x
        New-Screensaver
    }
)


$window.ShowDialog()

