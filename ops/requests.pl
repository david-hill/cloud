#use Date::Parse;
use Time::Local;

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
            } else {
                    $req{$treq}{'last-seen'}=timelocal($s, $M, $h, $d, $m, $y);
                    $req{$treq}{'elapsed'}=$req{$treq}{'last-seen'} - $req{$treq}{'first-seen'};
                    }
        }
}

foreach $req (sort keys %req) {
        print $req ."\t" .$req{$req}{'elapsed'} . "\n";
}

