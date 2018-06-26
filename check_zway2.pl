#!/usr/bin/env perl

use warnings;
use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use JSON;
use Nagios::Plugin;
use Data::Dumper;
use Encode;
use HTTP::Cookies;
use Switch;

use constant { true => 1, false => 0 };


my $np = Nagios::Plugin->new(
    usage => "Usage: %s -u|--url <http://user:pass\@host:port/url> -a|--attributes <attributes> "
    . "[ -c|--critical <thresholds> ] [ -w|--warning <thresholds> ] "
    . "[ -U|--ZWayUser ] "
    . "[ -P|--ZWayPassword ] "
    . "[ -D|--ZWayDevice ] " 
    . "[ -I|--ZWayInstance ] (default:0)"
    . "[ -C|--ZWayCommandClass ] "
    . "[ -M|--ZWayMeter ] "
    . "[ -t|--timeout <timeout> ] "
    . "[ --ignoressl ] "
    . "[ -h|--help ] ",
    version => '0.1',
    blurb   => 'Nagios plugin to check values from Z-Way using API without Virtual devices',
    extra   => "\nExample: \n"
    . "check_zway2.pl --url http://192.168.178.10:8083 -U youruser -P yourpassword"
    . "              -D 12 -C 49 -D 3 --warning :5 --critical :10 ",
    url     => 'http://www.creativeit.eu/software/nagios-plugins/check-zway2pl.html',
    plugin  => 'check_zway2',
    timeout => 15,
    shortname => "CheckZWAY2status"
);

# add valid command line options and build them into your usage/help documentation.

$np->add_arg(
    spec => 'url|u=s',
    help => '-u, --url http://user:pass@192.168.178.10:8083',
    required => 1,
);

$np->add_arg(
    spec => 'ZWayUser|U=s',
    help => '-U, --ZWayUser monitor',
    required => 1,
);

$np->add_arg(
    spec => 'ZWayPassword|P=s',
    help => '-P, --ZWayPassword monitor',
    required => 1,
);

$np->add_arg(
    spec => 'ZWayDevice|D=i',
    help => '-D, --ZWayDevice 12',
    required => 1,
);

$np->add_arg(
    spec => 'ZWayInstance|I=i',
    help => '-I, --ZWayInstance 0',
    default => 0,
    required => 0,
);

$np->add_arg(
    spec => 'ZWayCommandClass|C=i',
    help => '-C, --ZWayCommandClass 49',
    required => 1,
);

$np->add_arg(
    spec => 'ZWayMeter|M=i',
    help => '-M, --ZWayMeter 1',
    default => 9999,
    required => 0,
);

$np->add_arg(
    spec => 'warning|w=s',
    help => '-w, --warning INTEGER:INTEGER . See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);

$np->add_arg(
    spec => 'critical|c=s',
    help => '-c, --critical INTEGER:INTEGER . See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);

$np->add_arg(
    spec => 'ignoressl',
    help => "--ignoressl\n   Ignore bad ssl certificates",
);


####  Parse @ARGV and process standard arguments (e.g. usage, help, version)
$np->getopts;

my $opt_user = $np->opts->ZWayUser;
my $opt_pass = $np->opts->ZWayPassword;
my $opt_zd = $np->opts->ZWayDevice;
my $opt_zi = $np->opts->ZWayInstance;
my $opt_zc = $np->opts->ZWayCommandClass;
my $opt_zm = $np->opts->ZWayMeter;

if ($np->opts->verbose) { print "Verbose: Nagios Object \n"; print Dumper ($np);  print "#----\n" };


#### ----------- Useragent -----------

my $ua = LWP::UserAgent->new;
my $cookies = HTTP::Cookies->new( );

$ua->env_proxy;
$ua->cookie_jar( $cookies );
$ua->agent('check_zway2/1.0');
$ua->default_header('Accept' => 'application/json');
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->parse_head(0);
$ua->timeout($np->opts->timeout);

if ($np->opts->ignoressl) {
    $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
}

if ($np->opts->verbose) { print "Verbose: Useragent \n"; print Dumper ($ua);  print "#----\n" };


#### ----------- Auth -----------
my $url; 
my $response;

## Build Authentication URL
$url = $np->opts->url . "/ZAutomation/api/v1/login";
# verbose
if ($np->opts->verbose) { print "Verbose: Auth Url : " . $url . "\n#----\n" };

## Get Auth Response
$response = $ua->request( POST( $url, [ 'password' => $opt_pass , 'login' => $opt_user , 'rememberme' => false ]) );

# verbose
#if ($np->opts->verbose) { print "Verbose: Auth Response \n"; print Dumper ($response);  print "#----\n" };
if ($np->opts->verbose) { print "Verbose: Session Cookies \n"; print Dumper ($cookies);  print "#----\n" };


#### ----------- Data -----------

## Build Data URL
my $urlp = "/ZWaveAPI/Run/devices[" . $opt_zd . "].instances[" . $opt_zi . "].commandClasses[" . $opt_zc . "]" ;
if ($opt_zm != 9999) { $urlp = $urlp . ".data[" . $opt_zm . "]"; }

$url = $np->opts->url . $urlp;

# verbose
if ($np->opts->verbose) { print "Verbose: Data Url : " . $url . "\n#----\n" };

	
## Get Data Response
$response = $ua->request(GET $url, 'Content-type' => 'application/json');

if (not $response->is_success) {
    $np->nagios_exit(CRITICAL, "Connection to " . $urlp . " failed: ".$response->status_line);
}

# verbose
#if ($np->opts->verbose) { print "Verbose: Data Response \n"; print Dumper ($response);  print "#----\n" };


#### ----------- Parse -----------

## Parse JSON
my $json_response = decode_json($response->content);
if ($np->opts->verbose) { print "Verbose: JSON Response \n"; print Dumper ($json_response);  print "#----\n"};


## Compute value and limits
my @warning = split(',', $np->opts->warning);
my @critical = split(',', $np->opts->critical);


## Value depends on commandclass
my $check_value;
my $check_title;
my $check_probe;
my $check_value_tmp;
my $check_scale_tmp;
my $jsonxs = new JSON::XS;

switch ($opt_zc) {
  case 37 { 
            ## Command Class 37 - SwitchBinary
            if ($np->opts->verbose) { print "Verbose: Parsing commandclass " . $opt_zc ."\n#----\n"};
 
            $check_value_tmp = $jsonxs->encode ($json_response->{'data'}->{'level'}->{'value'});
            if ($check_value_tmp eq "true")
              { $check_value = 1  }
            elsif ($check_value_tmp eq "false")
              { $check_value = 0  }
            else         
              { $check_value = -1 }
            
            $check_title = "OnOff";
            $check_probe = "OnOff";
            $check_scale_tmp = "";
          }
  case 38 { 
            ## Command Class 38 - SwitchMultilevel
            if ($np->opts->verbose) { print "Verbose: Parsing commandclass " . $opt_zc ."\n#----\n"}; 
            $check_value = $json_response->{'data'}->{'level'}->{'value'};
            $check_title = "Level";
            $check_probe = "Level";
            $check_scale_tmp = "%";
          }
  case 49 { 
            ## Command Class 49 - MultiSensor
            if ($np->opts->verbose) { print "Verbose: Parsing commandclass " . $opt_zc ."\n#----\n"}; 
            $check_value = $json_response->{'val'}->{'value'};
            $check_title = $json_response->{'sensorTypeString'}->{'value'};
            $check_probe = $json_response->{'sensorTypeString'}->{'value'};
            $check_scale_tmp = $json_response->{'scaleString'}->{'value'};
          }
  case 50 { 
            ## Command Class 50 - Meter / MultiSensor
            if ($np->opts->verbose) { print "Verbose: Parsing commandclass " . $opt_zc ."\n#----\n"}; 
            $check_value = $json_response->{'val'}->{'value'};
            $check_title = $json_response->{'sensorTypeString'}->{'value'};
            $check_probe = $json_response->{'sensorTypeString'}->{'value'};
            $check_scale_tmp = $json_response->{'scaleString'}->{'value'};
          }
  case 67 { 
            ## Command Class 67 - Thermostat
            if ($np->opts->verbose) { print "Verbose: Parsing commandclass " . $opt_zc ."\n#----\n"}; 
            $check_value = $json_response->{'val'}->{'value'};
            $check_title = $json_response->{'modeName'}->{'value'};
            $check_probe = $json_response->{'modeName'}->{'value'};
            $check_scale_tmp = $json_response->{'scaleString'}->{'value'};
          }
  case 113 { 
            ## Command Class 113 - SensorBinary
            if ($np->opts->verbose) { print "Verbose: Parsing commandclass " . $opt_zc ."\n#----\n"}; 
            $check_value = $json_response->{'eventMask'}->{'value'};
            $check_title = $json_response->{'typeString'}->{'value'};
            $check_probe = $json_response->{'typeString'}->{'value'};
            $check_scale_tmp = "Mask";
          }
  case 128 { 
            ## Command Class 128 - Battery
            if ($np->opts->verbose) { print "Verbose: Parsing commandclass " . $opt_zc ."\n#----\n"}; 
            $check_value = $json_response->{'data'}->{'last'}->{'value'};
            $check_title = "Battery";
            $check_probe = "Battery";
            $check_scale_tmp = "%";
          }
  else { 
         if ($np->opts->verbose) { print "Verbose: Parsing commandclass " . $opt_zc ."\n#----\n"};
         $check_value = -1;
         $check_title = "commandclass " . $opt_zc . " is not supported";
         $check_probe = "commandclass " . $opt_zc . " is not supported";
         $check_scale_tmp = "";
       }
}

# Convert scales like "\x{b0}C for degree"
my $tmpenc = encode('UTF-8',$check_scale_tmp);
my $check_scale = encode('iso-8859-1',$tmpenc);

# Check if scale is an allowed value [[u|m]s % B c}]
my $check_scale_in_list = 0;
if ($check_scale eq "s" ) { $check_scale_in_list = 1; }
if ($check_scale eq "us") { $check_scale_in_list = 1; }
if ($check_scale eq "ms") { $check_scale_in_list = 1; }
if ($check_scale eq "%" ) { $check_scale_in_list = 1; }
if ($check_scale eq "B" ) { $check_scale_in_list = 1; }
if ($check_scale eq "c" ) { $check_scale_in_list = 1; }

### Smartmatch is experimental
#if($check_scale ~~ [ "s", "us", "ms", "%", "B", "c" ] ) {
#	$check_scale_in_list = 1;
#}


# Check value against thresholds...
my $result = -1;
$result = $np->check_threshold(
    check => $check_value,
    warning => $np->opts->warning,
    critical => $np->opts->critical
 );

if ($np->opts->verbose) { 
	print "Verbose: Value $check_value "; 
	print "\n         Scale $check_scale"; 
	print "\n         Title $check_title"; 
	print "\n         Probe $check_probe"; 
	print "\n#----\n"
};


#### Compute value and limits

my @statusmsg;

if ($check_scale_in_list eq 1) {
	push(@statusmsg, "$check_probe: ".$check_value.$check_scale);
	$np->add_perfdata(
		label => $check_title,
		value => $check_value,
		uom => $check_scale, 
		threshold => $np->set_thresholds( warning => $np->opts->warning, critical => $np->opts->critical),
	); 
} else {
	push(@statusmsg, "$check_probe: ".$check_value);
	$np->add_perfdata(
		label => $check_title . "(" . $check_scale . ")",
		value => $check_value,
		threshold => $np->set_thresholds( warning => $np->opts->warning, critical => $np->opts->critical),
	); 
};

if ($np->opts->verbose) { print "Verbose: StatusMsg"; print Dumper (@statusmsg);  print "#----\n"};


#### Finally

$np->nagios_exit(
    return_code => $result,
    message     => join(', ', @statusmsg),
);
