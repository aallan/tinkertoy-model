#!/Software/perl-5.8.8/bin/perl
 
  use strict;
  use warnings;
  
  use Carp;
  use Getopt::Long;
  use IO::Socket;
  use Net::Domain qw(hostname hostdomain);

  my ( $host, $port, $file, $string, $help );   
  my $status = GetOptions( "host=s"       => \$host,
                           "port=s"       => \$port,
                           "file=s"       => \$file,
			   "string=s"     => \$string,
			   "help!"        => \$help  );
  
  if( defined $help ) {
     print 
       "USAGE: $0 -string string [-file file] [-host host] [-port number]\n";
     exit;
  }   
  
  my $message;
  if ( defined $string ) {
     chomp( $string );
     $message = $string;
  } elsif ( defined $file ) {
     unless ( open ( FILE, "<$file") ) {
        croak( "ERROR: Cannot open $file" );
     }
     undef $/;
     $message = <FILE>;
     close FILE;
  } else {
     $message = "ping";
  }   
  
  unless ( defined $host ) {
     $host = hostname() . "." . hostdomain();
  }
  
  unless( defined $port ) {
     $port = 8000;
  }   
       
  my $sock = new IO::Socket::INET(  PeerAddr => $host,
                                    PeerPort => $port,
                                    Proto    => "tcp" );
                                    
  unless ( $sock ) {
      my $error = "$!";
      chomp($error);
      croak($error);
    
  } else { 
      
      # work out message length
      my $bytes = pack( "N", length($message) );
       
      # send message                                   
      print "Sending " . length($message) . " bytes to " . $host . "\n";
      print $sock $bytes;
      $sock->flush();
      print $sock $message;
      $sock->flush();  
          
      # grab response
      print "Waiting for response from server...\n";
      
      my ( $response, $reply_bytes, $reply_length );
      read $sock, $reply_bytes, 4;
      $reply_length = unpack( "N", $reply_bytes );
      read $sock, $response, $reply_length; 

      print "Read " . $reply_length . " bytes from " . $host . "\n";      
      close($sock);
      
      print "Response: " . $response ."\n";
  
   } 
  
  exit;                                     
  
