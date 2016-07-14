#!/Software/perl-5.8.8/bin/perl
 
  use strict;
  use warnings;
  use vars qw/$VERSION/;

  $VERSION = 1.0;
  
  use lib "../lib/perl5";
  use Agent::Util qw/:all/;
  use Carp;
  use Getopt::Long;
  use IO::Socket;
  use Net::Domain qw(hostname hostdomain);

  unless( scalar @ARGV >= 1 ) {
     die "USAGE: $0 -agent integer [-message string]\n";
  }

  my ( $number, $string, $help );   
  my $status = GetOptions( "agent=s"     => \$number,
			   "message=s"    => \$string,
			   "help!"       => \$help  );
  
  if( defined $help ) {
     print "USAGE: $0 -agent integer [-message string]\n";
     exit;
  }   
  
  my $message;
  if ( defined $string ) {
     chomp( $string );
     $message = $string;
  } else {
     $message = "ping";
  }   
  
  my $response;
  eval { $response = Agent::Util::send_message( $number, $message ); };
  if( $@ ) {
     croak( "Can not contact agent($number)" );
  }   
  
  print "Response: " . $response ."\n";
  exit;                                     
  
