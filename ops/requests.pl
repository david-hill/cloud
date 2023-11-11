#use Date::Parse;
use Time::Local;
sub convertdate() {
        $value=shift;
          my ($sec, $min, $hour, $day,$month,$year) = (localtime($value))[0,1,2,3,4,5];
          $year += 1900;
          $month += 1;
          $month = &pad($month);
          $day = &pad($day);
          $hour = &pad($hour);
          $min = &pad($min);
          $sec = &pad($sec);
          return "$year-$month-$day|$hour:$min:$sec";
}
sub pad() {
        $value = shift;
        if ($value < 10) {
                $value = "0$value";
        }
        return $value;
}

`zcat */var/log/containers/heat/heat-engine*gz > req`;
`cat */var/log/containers/heat/heat-engine.log */var/log/containers/heat/heat-engine.log.1 >> req`;
open READ, "req";
while (<READ>) {
        if ($_ =~ /^([0-9]+)-([0-9]+)-([0-9]+) ([0-9]+):([0-9]+):([0-9]+)\.[0-9]+/) {
                $y = $1;
                $m = $2;
                $d = $3;
                $h = $4;
                $M = $5;
                $s = $6;
        }
        if ($_ =~ /(req-[a-z0-9-]+)/) {
             $treq=$1;
             if (! $req{$treq}{'first-seen'} ){
                    $req{$treq}{'first-seen'}=timelocal($s,$M,$h, $d, $m, $y);
                    $req{$treq}{'last-seen'}=$req{$treq}{'first-seen'};
                    $req{$treq}{'elapsed'}=0;
            } else {
                    $req{$treq}{'last-seen'}=timelocal($s, $M, $h, $d, $m, $y);
                    $req{$treq}{'elapsed'}=$req{$treq}{'last-seen'} - $req{$treq}{'first-seen'};
            }
        }
}
foreach $req (sort keys %req) {
        if ($req{$req}{'elapsed'} > 0) {
          $endtime=&convert_date($req{$req}{'last-seen'});
          $starttime=&convert_date($req{$req}{'first-seen'});
          print $req ."\t$starttime\t$endtime\t" .$req{$req}{'elapsed'} . "\n";
        }
}
