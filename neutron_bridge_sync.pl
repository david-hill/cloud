#!/usr/bin/perl
my %usedbridgelist;
my $debug=1;
#  ovs-vsctl list-ports br-int
open READ, "cat /etc/libvirt/qemu/*.xml  |grep qbr | awk -F\\' \'{ print $2 }\'| ";
while (<READ>) {
  if ($_ =~ /qbr/) {
    @split = split /'/,$_;
    my $bridge = $split[1];
    $usedbridgelist{$bridge}++;
    print $bridge . "\n" if ($debug);
  }
}
#cat /etc/libvirt/qemu/*.xml | grep "qbr" | awk -F \' '{ print $2 }'
open READ, "brctl show | ";
while (<READ>) {
  chop $_;
  if ($_ =~ /qbr/) {
    my @split = split /\t/, $_;
    print $split[0], " " , $split[5], "\n" if ($debug);
    $presentbridge{$split[0]}=$split[5];
  }
}
foreach my $bridge (sort keys %presentbridge) {
  if ($usedbridgelist{$bridge}) {
    print "keeping $bridge\n";
  } else {
    `ifconfig $bridge down`;
    `brctl delif $bridge $presentbridge{$bridge}`;
    `brctl delbr $bridge`;
    print "Deleting $bridge and $presentbridge{$bridge}\n";
    my $ovsbridge=$bridge;
    $ovsbridge=~s/qbr/qvo/g;
    `ovs-vsctl del-port $ovsbridge`;
  }
}
