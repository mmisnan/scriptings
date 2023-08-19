#!/usr/bin/env perl
## aprs-output provided by daniestevez
## axudp extensions provided by dl9rdz
## To run: rec -t wav -r 48000 - 2>/dev/null | \
##  sox - -t wav - lowpass 2800 | \
##  ./weathex -b | \
##  ./pos2aprs.pl CALLSIGN passcode "Radiosonda AEMET LEMD" | \
##  nc rotate.aprs2.net 14580 > /dev/null

use strict;
use warnings;
use IO::Socket::INET;
use Getopt::Long;

my $filename = undef;
my $date = undef;

my $mycallsign;
my $passcode;
my $comment";

my $udp;
GetOptions("u=s" => \$udp) or die "Error in command line arguments\n";

while (@ARGV) {
  $mycallsign = shift @ARGV;
  $passcode = shift @ARGV;
  $comment = shift @ARGV;
  $filename = shift @ARGV;
}

my $fpi;

if (defined $filename) {
  open($fpi, "<", $filename) or die "Could not open $filename: $!";
}
else {
  $fpi = *STDIN;
}

my $fpo = *STDOUT;


my $line;

my $hms;
my $lat; my $lon; my $alt;
my $sign = 1;
my $NS; my $EW;
my $str;

my $speed = 0.00;
my $course = 0.00;

my $callsign;

my $temp;

# axudp: encodecall: encode single call sign ("AB0CDE-12*") up to 6 letters/numbers, ssid 0..15, optional "*"; last: set in last call sign (dst/via)
sub encodecall{
	my $call = shift;
	my $last = shift;
	if(!($call =~ /^([A-Z0-9]{1,6})(-\d+|)(\*|)$/)) {
		die "Callsign $call not properly formatted";
	};
	my $callsign = $1 . ' 'x(6-length($1));
	my $ssid = length($2)>0 ? 0-$2 : 0;
	my $hbit = $3 eq '*' ? 0x80 : 0;
	my $encoded = join('',map chr(ord($_)<<1),split //,$callsign);
	$encoded .= chr($hbit | 0x60 | ($ssid<<1) | ($last?1:0));
	return $encoded;
}

# kissmkhead: input: list of callsigns (dest, src, repeater list); output: raw kiss frame header data
sub kissmkhead {
	my @calllist = @_;
	my $last = pop @calllist;
	my $enc = join('',map encodecall($_),@calllist);
	$enc .= encodecall($last, 1);
	return $enc;
}

#create CRC tab
my @CRCL;
my @CRCH;
my ($c, $crc,$i);
for $c (0..255) {
	$crc = 255-$c;
	for $i (0..7) {  $crc = ($crc&1) ? ($crc>>1)^0x8408 : ($crc>>1); }
	$CRCL[$c] = $crc&0xff;
	$CRCH[$c] = (255-($crc>>8))&0xff;
}
sub appendcrc {
	$_ = shift;
	my @data = split //,$_;
	my ($b, $l, $h)=(0,0,0);
	for(@data) { $b = ord($_) ^ $l; $l = $CRCL[$b] ^ $h; $h = $CRCH[$b]; }
	$_ .= chr($l) . chr($h);
	return $_;
}

my ($sock,$kissheader);
if($udp) {
	my ($udpserver,$udpport)=split ':',$udp;
	$udpserver = "127.0.0.1" unless $udpserver;
	$sock = new IO::Socket::INET(PeerAddr => $udpserver, PeerPort => $udpport, Proto => "udp", Timeout => 1) or die "Error creating socket";
	# $kissheader = kissmkhead("APRS",uc($mycallsign),"TCPIP*");
	$kissheader = kissmkhead("APRS",uc($mycallsign));
}

print $fpo "user $mycallsign pass $passcode vers \"RS decoder\"\n";

my $actiontime = time();
while ($line = <$fpi>) {
    my ($serialno, $runno, $gpsdata, $ok) = $line =~ /\(([^)]+)\)\s*\[\s*([^]]+)\s*\]\s*([^[]+)\[\s*([^]]+)\s*\]/;
    if (index($line, "[OK]") != -1) {	
	my ($alt_s) = $gpsdata =~ /alt: ([\d\.]+)/;
	my ($lat_s) = $gpsdata =~ /lat: ([\d\.]+)/;
	my ($lat_d, $lat_m) = split /\./, $lat_s;
	my ($lon_s) = $gpsdata =~ /lon: ([\d\.]+)/;
	my ($lon_d, $lon_m) = split /\./, $lon_s;
	my ($hr, $min, $sec) = $gpsdata =~ /(\d{2}):(\d{2}):(\d{2})/;

        $hms = $hr*10000+$min*100+$sec;

        if ($lat_d < 0) { $NS="S"; $sign *= -1; }
        else        { $NS="N"; $sign = 1}
        $lat = $sign*$lat_d*100+$lat_m*60;

        if ($lon_d < 0) { $EW="W"; $sign = -1; }
        else        { $EW="E"; $sign = 1; }
        $lon = $sign*$lon_d*100+$lon_m*60;

        $alt = $alt_s*3.28084; ## m -> feet

        $callsign = $serialno;
        $temp = "";
        
	if ( time() >= $actiontime ) {
          $str = sprintf("$mycallsign>APRS,TCPIP*:;%-9s*%06dh%07.2f$NS/%08.2f${EW}O%03d/%03d/A=%06d$comment$temp", $callsign, $hms, $lat, $lon, $course, $speed, $alt);
          print $fpo "$str\n";
          if($sock) {
	        $str = (split(":",$str))[1];
		print $sock appendcrc($kissheader.chr(0x03).chr(0xf0).$str);
	  }
          $actiontime += 10; 
	}

    }
}

close $fpi;
close $fpo;

