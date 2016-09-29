package Rplus::Util::PhoneNum;

use Rplus::Modern;
use Exporter qw(import);

our @EXPORT_OK = qw(refine_phonenum);


sub refine_phonenum {
  my $phone_num = shift;

  return unless $phone_num;

  $phone_num =~ s/\D//g;

  return $phone_num;
}

1;
