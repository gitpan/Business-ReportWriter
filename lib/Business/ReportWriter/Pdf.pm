package Business::ReportWriter::Pdf;

use POSIX qw(setlocale LC_NUMERIC);
use utf8;
use PDF::Report;

use Business::ReportWriter;

@ISA = ("Business::ReportWriter");

sub fields {
  my ($self, $parms) = @_;
  $self->SUPER::fields($parms);
  my @fields = @$parms;
# Find maximum line height
  $self->{font}{maxheight} = 8;
  for (0..$#{ $self->{report}{fields} }) {
    $self->{fields}{$fields[$_]{name}} = $_;
    if (defined($fields[$_]{font}{size}) &&
      $fields[$_]{font}{size} > $self->{font}{_maxheight}) {
      $self->{font}{_maxheight} = $fields[$_]{font}{size};
    }
  }
}
# Routines for report writing
sub calcYoffset {
  my ($self, $fontsize) = @_;
  $self->{ypos} -= $fontsize + 2;
  return $self->{ypos};
}

sub footer {
  my ($self, $fontsize) = @_;
  my $break = '_page';
  $self->{breaks}{$break} = '_break';
  my $text = $self -> makeHeadertext(0, $self->{report}{breaks}{$break}{text});
  $self->{breaktext}{$break} = $text;
  $self -> printBreak();
  $self->{breaks}{$break} = "";
}

sub makePagefunc {
  my ($page, $func) = @_;
  my @fields = ($func =~ /\$(\w*)/g);
  for my $field (@fields) {
    $func =~ s/\$$field/\$page->{$field}/g;
  }
  my $text;
  setlocale(LC_NUMERIC, $self->{report}{locale});
  eval('$text = ' . $func);
  setlocale( LC_NUMERIC, "C" );
  return $text;
}

sub makePagetext {
  my ($page, $text) = @_;
  my @fields = ($text =~ /\$(\w*)/g);
  for my $field (@fields) {
    $text =~ s/\$$field/$page->{$field}/eg;
  }
  return $text;
}

sub headerText {
  my $self = shift;
  my $p = $self->{pdf};
  my $page = $self->{pageData};
  for my $th (@{ $self->{report}{page}{text} }) {
    my $text;
    next if (defined($th->{depends}) && 
      !eval($self -> makePagetext($page, $th->{depends})));
    if (defined($th->{function})) {
      $text = makePagefunc($page, $th->{function});
    } else {
      $text = makePagetext($page, $th->{text});
    }
    $self->{ypos} = $self->{paper}{topmargen}-mmtoPt($th->{ypos})
     if $th->{ypos};
    if (defined($th->{font})) {
      $self->{font}{size} = $th->{font}{size} if $th->{font}{size};
      $self->{font}{face} = $th->{font}{face} if $th->{font}{face};
    }
    next if !$text;
    $p->setSize($self->{font}{size}+0);
    $p->setFont($self->{font}{face});
    $self->outText($text, $th->{xpos}, $self->{ypos}, $th->{align});
    $self -> calcYoffset($self->{font}{size}) unless $th->{sameline};
  }
}

sub printPageheader {
  my $self = shift;
  my $p = $self->{pdf};
  $self->{ypos} = $self->{paper}{topmargen} -
    mmtoPt($self->{report}{page}{number}{ypos})
    if $self->{report}{page}{number}{ypos};
  $self->outText($self->{report}{page}{number}{text}.$self->{pageData}{pagenr},
    $self->{report}{page}{number}{xpos},
    $self->{ypos}, $self->{report}{page}{number}{align}
  );
  $self -> calcYoffset($self->{font}{size}
  );
}

sub bodyStart {
  my $self = shift;
  my $p = $self->{pdf};
  my $body = $self->{report}{body};
  if (defined($body->{font})) {
    $self->{font}{size} = $body->{font}{size} if $body->{font}{size};
    $self->{font}{face} = $body->{font}{face} if $body->{font}{face};
  }
  $p->setSize($self->{font}{size}+0);
  $p->setFont($self->{font}{face});
  $self->{ypos} = $self->{paper}{topmargen}-mmtoPt($body->{ypos})
   if $body->{ypos};
  my $heigth = mmtoPt($body->{heigth}) if $body->{heigth};
  $heigth += mmtoPt($body->{ypos}) if $body->{ypos};
  $self->{paper}{heigth} = $heigth if $heigth;
  for (@{ $self->{report}{fields} }) {
    $self->outText($_->{text}, $_->{xpos}, $self->{ypos}, $_->{align});
  }
}

sub drawGraphics {
  my $self = shift;
  my $p = $self->{pdf};
  my $graphics = $self->{report}{graphics};
  $p->setGfxLineWidth($graphics->{width}+0) if defined($graphics->{width});
  for (@{ $graphics->{boxes} }) {
    my $bottomy = $self->{paper}{topmargen}-mmtoPt($_->{bottomy});
    my $topy = $self->{paper}{topmargen}-mmtoPt($_->{topy});
    $p->drawRect(mmtoPt($_->{topx}), $bottomy,
      mmtoPt($_->{bottomx}), $topy
    );
  }
}

sub drawLogos {
  my $self = shift;
  my $p = $self->{pdf};
  my $logos = $self->{report}{logo};
  for (@{ $logos->{logo} }) {
    my $x = mmtoPt($_->{x});
    my $y = $self->{paper}{topmargen}-mmtoPt($_->{y});
    $p->addImgScaled($_->{name}, $x, $y, $_->{scale});
    #!!$p->importepsfile($_->{name}, mmtoPt($_->{topx}), mmtoPt($_->{topy}),
    #!!  mmtoPt($_->{bottomx}), mmtoPt($_->{bottomy}));
  }
}

sub newPage {
  my $self = shift;
  my $p = $self->{pdf};
  $self->{pageData}{pagenr}++;
  $self->{breaks}{'_page'} = "";
  $self -> footer() if $self->{pageData}{pagenr} > 1;
  $self->{ypos} = $self->{paper}{topmargen};
  $p->newpage;
  $self->{font}{size} = $self->{report}{page}{font}{size};
  $self->{font}{face} = $self->{report}{page}{font}{face};
  $p->setSize($self->{font}{size}+0);
  $p->setFont($self->{font}{face});
  $self -> headerText();
  $self -> printPageheader() if defined($self->{report}{page}{number});
  $self -> bodyStart();
  $self -> drawGraphics();
  $self -> drawLogos();
}

sub setLinefont {
  my ($self, $fld) = @_;
  if (defined($fld->{font})) {
    $self->{font}{size} = $fld->{font}{size} if $fld->{font}{size};
    $self->{font}{face} = $fld->{font}{face} if $fld->{font}{face};
  }
}

sub initLine {
  my ($self, $rec) = @_;
  my $fontsize = $self->{font}{_maxheight};
  $self -> calcYoffset($fontsize);
}

sub initField {
  my ($self, $field) = @_;
  my $p = $self->{pdf};
  $self -> setLinefont($field);
  my $fontsize = $self->{font}{size}+0;
  $p->setFont($self->{font}{face});
  $self -> calcYoffset($fontsize) if defined($field->{nl});
}

sub outField {
  my ($self, $text, $field) = @_;
  $self->outText($text, $field->{xpos}, $self->{ypos}, $field->{align});
}

sub setBreakfont {
  my ($self, $break) = @_;
  if (defined($self->{report}{breaks}{$break}{font})) {
    $self->{font}{size} = $self->{report}{breaks}{$break}{font}{size}
      if $self->{report}{breaks}{$break}{font}{size};
    $self->{font}{face} = $self->{report}{breaks}{$break}{font}{face}
      if $self->{report}{breaks}{$break}{font}{face};
  }
}

sub printBreak {
  my $self = shift;
  my $p = $self->{pdf};
  for my $break (@{ $self->{report}{breaks}{order} }) {
    my $self_break = $self->{breaks}{$break} || '';
    if ($self_break eq '_break') {
      $self -> setBreakfont($break);
      $self -> calcYoffset($self->{font}{size});
      #$p->setSize($self->{font}{size}+0);
      $p->setFont($self->{font}{face});
      if (defined($self->{report}{breaks}{$break}{total})) {
        my $self_breaktext = $self->{breaktext}{$break} || '';
        $self->outText("Total $self_breaktext",
          $self->{report}{breaks}{$break}{xpos}, $self->{ypos});
        foreach my $tot (@{ $self->{report}{breaks}{$break}{total} }) {
          my $amount = $self->{totals}{$break}{$tot};
          if ($self->{report}{breaks}{$break}{format}) {
            setlocale(LC_NUMERIC, $self->{report}{locale});
            $amount = sprintf($self->{report}{breaks}{$break}{format}, $amount);
            setlocale( LC_NUMERIC, "C" );
          }
          my $fldno = $self->{fields}{$tot};
          my $field = $self->{report}{fields}[$fldno];
          $self->outText($amount, $field->{xpos}, $self->{ypos}, $field->{align});
          $self->{totals}{$break}{$tot} = 0;
        }
      }
    }
  }
}

sub printBreakheader {
  my ($self, $rec, $break) = @_;
  my $p = $self->{pdf};
  $self -> setBreakfont($break);
  $self -> calcYoffset($self->{font}{size});
  $p->setSize($self->{font}{size}+0);
  $p->setFont($self->{font}{face});
  my $text = $self -> makeHeadertext($rec,
    $self->{report}{breaks}{$break}{text});
  $self->outText($text, $self->{report}{breaks}{$break}{xpos}, $self->{ypos});
  $self->{breaktext}{$break} = $text;
}

sub printList {
  my ($self, $list, $page) = @_;
  my @list = @$list;
  $self->{pageData} = $page;
  my $papersize = $self->{report}{papersize} || 'A4';
  my $orientation = $self->{report}{orientation} || 'Portrait';
  my $p = new PDF::Report(
    PageSize => $papersize,
    PageOrientation => $orientation
  );

  $self->{pdf} = $p;
  $self->{ypos} = -1;
  $self -> paperSize();

  foreach my $rec (@list) {
    my $bottommargen = $self->{paper}{topmargen} - $self->{paper}{heigth};
    $self -> newPage() if $self->{ypos} < $bottommargen;
    $self -> processTotals($rec);
    $self -> printLine($rec);
  }
  $self -> endPrint();
}

sub printDoc {
  my ($self, $filename) = @_;
  my $p = $self->{pdf};
  if ($filename) {
    open OUT, ">$filename";
    print OUT $p->Finish("none");
    close OUT;
  }
}

sub paperSize {
  my $self = shift;
  my $p = $self->{pdf};
  my ($pagewidth, $pageheigth) = $p->getPageDimensions();
  $self->{paper} = {
    width => $pagewidth,
    topmargen => $pageheigth-20,
    heigth => $self->{paper}{topmargen}
  };
}

sub outText {
  my ($self, $text, $x, $y, $align) = @_;
  my $p = $self->{pdf};
  $x = mmtoPt($x);
##
##print "$text er utf8\n" if utf8::is_utf8($text);
##print "$text er ikke utf8\n" unless utf8::is_utf8($text);
utf8::decode($text);
  utf8::decode($text) if utf8::is_utf8($text);
  my $sw = 0;
  $sw = int($p->getStringWidth($text)+.5) if lc($align) eq 'right';
  $x -= $sw;
  my $margen = 20;
  my $width = $self->{paper}{width}-$x-20;
  $p->addParagraph($text, $x, $y,
    $self->{paper}{width}-$x-20,
    $self->{paper}{topmargen}-$y, 0
  );
  my ($hPos, $vPos) = $p->getAddTextPos();
  $self->{ypos} = $vPos;
}

sub mmtoPt {
  my $mm = shift;
  return int($mm/.3527777);
}

1;
