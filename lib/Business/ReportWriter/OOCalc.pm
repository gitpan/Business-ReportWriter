package Business::ReportWriter::OOCalc;

use POSIX qw(setlocale LC_NUMERIC);
use utf8;
use OpenOffice::OOCBuilder;

use Business::ReportWriter;

@ISA = ("Business::ReportWriter");

sub initLine {
  my ($self, $rec) = @_;
  $self->{rownr}++;
  $self->{fieldnr} = 0;
}

sub initField {
  my ($self, $field) = @_;
  $self->{fieldnr}++;
}

sub outField {
  my ($self, $text, $field) = @_;
  $self->outText($text);
}

sub printBreak {
  my $self = shift;
  my $sheet = $self->{sheet};
  for my $break (@{ $self->{report}{breaks}{order} }) {
    my $self_break = $self->{breaks}{$break} || '';
    if ($self_break eq '_break') {
      if (defined($self->{report}{breaks}{$break}{total})) {
        my $self_breaktext = $self->{breaktext}{$break} || '';
        $self->{rownr}++;
        $self->{fieldnr} = 0;
        $self->outText("Total $self_breaktext");
        foreach my $tot (@{ $self->{report}{breaks}{$break}{total} }) {
          my $amount = $self->{totals}{$break}{$tot};
          if ($self->{report}{breaks}{$break}{format}) {
            setlocale(LC_NUMERIC, $self->{report}{locale});
            $amount = sprintf($self->{report}{breaks}{$break}{format}, $amount);
            setlocale( LC_NUMERIC, "C" );
          }
          my $fldno = $self->{fields}{$tot};
          my $field = $self->{report}{fields}[$fldno];
          $self->outText($amount);
          $self->{totals}{$break}{$tot} = 0;
        }
      }
    }
  }
}

sub printBreakheader {
  my ($self, $rec, $break) = @_;
  my $sheet = $self->{sheet};
  my $text = $self -> makeHeadertext($rec,
    $self->{report}{breaks}{$break}{text});
  $self->outText($text);
  $self->{breaktext}{$break} = $text;
}

sub printList {
  my ($self, $list, $page) = @_;
  my @list = @$list;
  $self->{pageData} = $page;
  my $sheet=OpenOffice::OOCBuilder->new();

  $self->{sheet} = $sheet;

  foreach my $rec (@list) {
    $self -> processTotals($rec);
    $self -> printLine($rec);
  }
  $self -> endPrint();
}

sub printDoc {
  my ($self, $filename) = @_;
  my $sheet = $self->{sheet};
  if ($filename) {
    $sheet->generate ($filename)
  }
}

sub outText {
  my ($self, $text) = @_;
  my $sheet = $self->{sheet};
  $sheet->goto_xy($self->{fieldnr}, $self->{rownr});
  utf8::decode($text);
  $sheet->set_data($text);
  print "$self->{rownr} $self->{fieldnr}: $text\n";
}

1;
