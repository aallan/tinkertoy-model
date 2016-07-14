#!/Software/perl-5.8.8/bin/perl
 
  use strict;
  use warnings;
  use sigtrap qw/die normal-signals error-signals/;
  $SIG{'INT'} = \&stop;
  
  use lib "../lib/perl5";
  use IO::TCP::Server qw/:all/;
  use Data::Dumper;
  
  my $server = new IO::TCP::Server();
  print "Starting server on $server->{HOST}:$server->{PORT}\n";
  
  my ( $listen, $buffer );
  while ( $listen = $server->socket()->accept() ) {
      
      # read incoming message from socket
      my $length;
      my $bytes_read = sysread( $listen, $length, 4 );
      $length = unpack( "N", $length );
      $bytes_read = sysread( $listen, $buffer, $length);
      print "RX: $buffer ($length bytes)\n";  
      
      # handle message
      my $response = handle( $buffer );
            
      # return an ACK message to client
      my $return_bytes = pack( "N", length( $response ) );
      print "TX: $response (" . length($response) . " bytes)\n";      

      print $listen $return_bytes;
      $listen->flush();
      print $listen $response;
      $listen->flush();
      close ($listen);
  }   
  
  sub handle {
     my $message = shift;
       
     if( $message eq "ping" ) {
       return "ack";
     } else {
       return "unknown";
     }    
     
  }
  
  sub stop {
    print "Shutting down server...\n";
    $server->cleanup();
  }
  
  
  exit;                                     
  
