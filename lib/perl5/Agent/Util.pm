package Agent::Util;

  use strict;
  use warnings;
  use vars qw/$VERSION @EXPORT_OK %EXPORT_TAGS @ISA/;
  @ISA = qw(Exporter);
  @EXPORT_OK = qw( contact_details send_message list_of_agents number_of_agents 
     pids_of_agents reset_agents poll_agents fork_agent pick_random_agent );
  %EXPORT_TAGS = ( 'all' => [qw( contact_details send_message list_of_agents
     number_of_agents pids_of_agents reset_agents poll_agents fork_agent 
     pick_random_agent)]);
  
  $VERSION = 1.0;
  
  use Carp;
  use Config::Simple;
  use Config::User;
  use Data::Dumper;
  use Fcntl qw/:flock/;
  use File::Spec;
  use IO::Socket;
  use Net::Domain qw(hostname hostdomain);
  use POSIX qw/:sys_wait_h/;
  use Errno qw/EAGAIN/;

  # returns pid, host and port number for agent $number
  sub contact_details {
     
     croak( 'Usage: contact_details( $number, [ $directory ] )' ) 
                                                unless scalar(@_) >= 1;
     my $number = shift;
     my $directory = shift if @_; 
    
     # get directory name
     my $dir;
     unless ( defined $directory ) {
        $dir =  File::Spec->catfile( Config::User->Home(), '.tinkertoy' );
     } else {
        $directory = lc($directory);
        $dir = File::Spec->catfile( Config::User->Home(), ".$directory" );
     }    
     
     # get file name
     my $file = File::Spec->catfile( $dir, "serversocket.$number" );
     
     # grab contents of socket file
     my $string;
     unless ( open( SOCKETFILE, "<$file" ) ) {
        croak( "Can not open $file for read only access" );    
     } else {
        unless ( flock( SOCKETFILE, LOCK_EX ) ) {
           croak("Unable to acquire exclusive lock: $!");
        }   
	undef $/;
        $string = <SOCKETFILE>;
        close (SOCKETFILE);
     }
     
     # parse file
     my ( $pid, $host, $port ) = split( / /, $string );

     # return host and port for agent $number
     #print "Agent($number) found at $host:$port\n";
     return ($pid, $host, $port );
      
  }
  

  # send message to agent $number and returns response given
  sub send_message {
     
     croak( 'Usage: send_message( $number, $message, [ $directory ] )' ) 
                                                unless scalar(@_) >= 2;
     my $number = shift;
     my $message = shift;
     my $directory = shift if @_;  

     my ( $pid, $host, $port );
     eval {  if( defined $directory ) {
                ($pid, $host, $port) = contact_details( $number, $directory );
	     } else {
	        ($pid, $host, $port) = contact_details( $number ); 
	     }
     };
        
     if( $@ ) {
        croak( "Can not status file for agent($number)" );
     }   
       
     my $sock = new IO::Socket::INET(  PeerAddr => $host,
                                       PeerPort => $port,
                                       Proto    => "tcp" );
                                    
     my ( $response );
     unless ( $sock ) {
         my $error = "$!";
         chomp($error);
         croak($error);
    
     } else { 
      
         # work out message length
         my $bytes = pack( "N", length($message) );
       
         # send message                                   
         #print "Sending " . length($message) . " bytes to agent($number)\n";
         print $sock $bytes;
         $sock->flush();
         print $sock $message;
         $sock->flush();  
          
         # grab response
         #print "Waiting for response from server...\n";
      
         my ( $reply_bytes, $reply_length );
         read $sock, $reply_bytes, 4;
         $reply_length = unpack( "N", $reply_bytes );
         read $sock, $response, $reply_length; 

         #print "Read " . $reply_length . " bytes from agent($number)\n";      
         close($sock);
        
      }
      return $response; 
     
  }
  
  # returns list of agent contact files  
  sub list_of_agents {
  
     croak( 'Usage: list_of_agents( [ $directory ] )' ) if scalar(@_) >= 2;
     my $directory = shift if @_; 
    
     # get directory name
     my $dir;
     unless ( defined $directory ) {
        $dir =  File::Spec->catfile( Config::User->Home(), '.tinkertoy' );
     } else {
        $directory = lc($directory);
        $dir = File::Spec->catfile( Config::User->Home(), ".$directory" );
     }    
          
     # get list of files in ~/.tinkertoy directory
     my @files;
     if ( opendir (DIR, $dir )) {
        foreach ( readdir DIR ) {
	   next if $_ eq "state.dat";
	   next if $_ eq "state.dat.lock";
	   next if $_ eq ".";
	   next if $_ eq "..";
	   push ( @files, $_ );
	}
	closedir DIR;
     } else {
        croak( "Can not open $dir" );
     }
     @files = sort(@files);
     #use Data::Dumper; print Dumper( @files );
     
     return @files;	
  }  
  
  # returns list of agent contact files  
  sub number_of_agents {
  
     croak( 'Usage: number_of_agents( [ $directory ] )' ) if scalar(@_) >= 2;
     my $directory = shift if @_; 
    
     # get directory name
     my @files;
     if( defined $directory ) {
        @files = list_of_agents( $directory );
     } else {
        @files = list_of_agents( ); 
     }
     
     return scalar( @files );
  }  
    
  # returns list of the pids for all running agents
  sub pids_of_agents {
  
     croak( 'Usage: pids_of_agents( [ $directory ] )' ) if scalar(@_) >= 2;
     my $directory = shift if @_; 
    
     # get list of files
     my @files;
     if( defined $directory ) {
        @files = list_of_agents( $directory );
     } else {
        @files = list_of_agents( ); 
     }
     
     my @pids;
     foreach my $i ( 0 ... $#files ) {
        my ( $dummy, $agent ) = split( /\./, $files[$i] );
        my ( $pid, $host, $port ) = contact_details( $agent );
        push @pids, $pid;	
     }
     return @pids;     
     
  }  
    
  # returns list of agent contact files  
  sub reset_agents {
  
     croak( 'Usage: reset_agents( [ $directory ] )' ) if scalar(@_) >= 2;
     my $directory = shift if @_; 
    
     # get list of files
     my @files;
     if( defined $directory ) {
        @files = list_of_agents( $directory );
     } else {
        @files = list_of_agents( ); 
     }
     
     # send rest message to all agents
     foreach my $k ( 0 ... $#files ) {
        my ( $name, $number ) = split( /\./, $files[$k] );
        my $response;
        eval { $response = send_message($number, "reset"); };
        if( $@ ) {
           carp( "Can not contact agent($number)" );
        } 
     }       
   
     return 1;
     
  }   
  
  # poll all agents and return status
  sub poll_agents {
  
     croak( 'Usage: poll_agents( [ $directory ] )' ) if scalar(@_) >= 2;
     my $directory = shift if @_; 
    
     # get list of files
     my @files;
     if( defined $directory ) {
        @files = list_of_agents( $directory );
     } else {
        @files = list_of_agents( ); 
     }
     
     # send rest message to all agents
     my @status;
     my $coop_count = 0;
     my $defect_count = 0;
     foreach my $k ( 0 ... $#files ) {
        my ( $name, $number ) = split( /\./, $files[$k] );
        my $strategy;
        eval { $strategy = send_message($number, "ping"); };
        if( $@ ) {
           carp( "Can not contact agent($number)" );
        } 
	#print "Agent($number): $strategy\n";
	push @status, $strategy;
	$coop_count = $coop_count + 1 if $strategy eq "cooperate";
        $defect_count = $defect_count + 1 if $strategy eq "defect";
     }       
   
     return @status;
     
  }     
  
  # fork an agent process
  sub fork_agent {
    
    my $pid;
    my $count = 0;
    FORK: {
       if( $pid = fork() ) {
          return 1;
       } elsif ( defined $pid ) {
          exec ( "./agent.pl >&/dev/null");
#          exec ( "./agent.pl");
       } elsif ( $! == EAGAIN ) {
	  $count = $count + 1;
	  if ( $count <= 5 ) {
             print "Recoverable fork() error, retry $count.\n";
	     sleep 5;
	     redo FORK;
	  } else {
             carp( "Unable to fork() agent process, tired 5 times." );  
	     return 0;
	  }   
       } else {
          carp( "Unable to fork() agent process." );  
	  return 0;  
       }
    } 
    return 1;  
       
  }
  
  # pick a random agent from the available pool
  sub pick_random_agent {
  
     croak( 'Usage: pick_random_agent( [ $directory ] )' ) if scalar(@_) >= 2;
     my $directory = shift if @_; 
    
     # get list of files
     my @files;
     if( defined $directory ) {
        @files = list_of_agents( $directory );
     } else {
        @files = list_of_agents( ); 
     }
     my $agents = scalar( @files );
     
     my $random = int ( rand($agents) ) + 1;
     my ( $dummy, $agent ) = split( /\./, $files[$random-1] );

     return $agent;     
  }   
             
  1;   
  
