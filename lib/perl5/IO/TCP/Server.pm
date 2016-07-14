package IO::TCP::Server;  

  use strict;
  use warnings;
  use vars qw/$VERSION @EXPORT_OK %EXPORT_TAGS @ISA/;
  @ISA = qw(Exporter);
  @EXPORT_OK = qw(host port dir server_file cleanup socket id pid);
  %EXPORT_TAGS = (
        'all'    => [qw(host port dir server_file cleanup socket id pid)],
	'simple' => [qw(socket cleanup)] );
  
  $VERSION = 1.0;
  
  use Carp;
  use Config::Simple;
  use Config::User;
  use Data::Dumper;
  use File::Spec;
  use IO::Socket;
  use Net::Domain qw(hostname hostdomain);
  use Fcntl qw(:DEFAULT :flock);
  
  sub new {
     my $proto = shift;
     my $class = ref($proto) || $proto;
     
     my $block = bless { HOST => undef,
                         PORT => undef,
			 SOCK => undef,
			 FILE => undef,
			 DIR  => undef,
			 ID   => undef }, $class;
     $block->configure( @_ );	
     
     return $block;		 
  }
  
  sub configure {
     my $self = shift;
     my %args = @_;
     
     for my $key ( qw/ Host Dir / ) {
        my $method = lc($key);
	$self->$method( $args{$key} ) if exists $args{$key};
     }	
     
     # define a default hostname if not a passed arguement
     my $host = hostname();
     my $domain = hostdomain();
     $self->{'HOST'} = "127.0.0.1" unless defined $self->{'HOST'};
     
     # check for presence (or create if absent) the logging directory
     my $dir;
     unless ( defined $self->{'DIR'} ) {
        $dir =  File::Spec->catfile( Config::User->Home(), '.tcpserver' );
     } else {
        my $directory = lc($self->{'DIR'});
        $dir = File::Spec->catfile( Config::User->Home(), ".$directory" );
     }
     		
     unless( opendir(DIR, $dir ) ) {
        mkdir $dir, 0755;
	if( opendir(DIR, $dir ) ) {
	   closedir DIR;
	} else {
	   croak( "Can not create directory $dir" );
	}
     }
     closedir DIR;
  		
     # start the server on an unused port above 8000
     my $sock = undef;
     my $start_port = 8000;
     my $using_port = $start_port;
     while( !defined $sock ) {
        $sock = new IO::Socket::INET( 
                    LocalHost => $self->{'HOST'},
                    LocalPort => $using_port,
                    Proto     => 'tcp',
                    Listen    => 1,
                    Reuse     => 1 );  
	
	unless ( defined $sock ) {
	  $using_port = $using_port + 1;
	}  	        
     
     }
     $self->{'PORT'} = $using_port;
   
     # check the current state file for unique ID, if no state file present
     # we need to create one since this is the first time we've been run.
     my $state_file = File::Spec->catfile( $dir, 'state.dat' );
     my $state = new Config::Simple( filename => $state_file );
     $state->syntax( 'ini' );
     $state->param( "file.name", $state_file );
   
     unless ( defined $state ) {
        croak( chomp( $Config::Simple::errstr ) );
     }

     my ( $number, $string );
     $number = $state->param( "server.unique_process" ); 
     print "\$number = $number\n";
     if ( ! defined $number || $number eq '' ) {
        # $number is not defined correctly (first ever run of the program?)
        $state->param( "server.unique_process", 0 );
        $number = 0; 
     }

     # increment ID number
     $number = $number + 1;
     print "\$number = $number\n";
     $state->param( "server.unique_process", $number );
     $self->{'ID'} = $number;
  
     # commit ID stuff to STATE file
     my $status = $state->save( $state_file );
     unless ( defined $status ) {
        croak( chomp( $Config::Simple::errstr ) );
     } 
   
     # create log file
     my $process = $state->param( "server.unique_process" );
     $self->{'FILE'} = File::Spec->catfile( $dir, "serversocket.$process" );
     unless( open( SOCKETFILE, "+>$self->{FILE}" ) ){
        croak( "Can not open $self->{FILE} for read/write access" );
     }
     		      	     
     # write to log file
     my $pid = $$;
     print SOCKETFILE "$pid $self->{HOST} $self->{PORT}";
     close SOCKETFILE;
     
     # stuff the IO::Socket into the Server object
     $self->{'SOCK'} = $sock;
  }   
  
  sub host {
     my $self = shift;
     
     if( @_ ) {
        $self->{'HOST'} = shift;
     }
     return $self->{'HOST'}
  }   	 
  
  sub dir {
     my $self = shift;
     
     if( @_ ) {
        $self->{'DIR'} = shift;
     }
     return $self->{'DIR'}
  }     
  
  sub port {
     my $self = shift;
     return $self->{'PORT'}
  } 
    
  sub server_file {
     my $self = shift;
     return $self->{'FILE'}
  } 
  
  sub socket {
     my $self = shift;
     return $self->{'SOCK'}
  } 
  
  sub id {
     my $self = shift;
     return $self->{'ID'}
  } 
  
  sub pid {
     my $self = shift;
     return $$;
  }   
      
  sub cleanup {
     my $self = shift;
     
     unless( unlink $self->{'FILE'} ) {
        carp( "Can not delete $self->{FILE} during cleanup" );  	 
     }
     close ( $self->{'SOCK'} );
  }
     
  1;
