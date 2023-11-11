use Date::Parse;


open READ, "req";
while (<READ>) {
        if ($_ =~ /^([0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+:[0-9]+\.[0-9]+)/) {
                $date=$1;
        }
        if ($_ =~ /(req-[a-z0-9-]+)/) {
                $treq=$1;
                if (! $req{$treq}{'first-seen'} ){
                    $req{$treq}{'first-seen'}=str2time($date);
            } else {
                    $req{$treq}{'last-seen'}=str2time($date);
                    $req{$treq}{'elapsed'}=$req{$treq}{'last-seen'} - $req{$treq}{'first-seen'};
                    }
        }
}

foreach $req (sort keys %req) {
        print $req ."\t" .$req{$req}{'elapsed'} . "\n";
}

