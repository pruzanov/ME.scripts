package DbLoader;

use strict;
use warnings;
use DBI;
use XML::Simple;
use Data::Dumper;
use constant DEBUG=>0;
#==========================PARAMETERS=============================
my $database = "data_clinic";
my $host     = "localhost";
my $user     = "modencode";
my $password = "modencode+++";
my $PCFLAG   = "!:"; # Use to prefix all machine reports entered into database
my %db_fields     = (f=>"tracks",c=>"citation",g=>"gbrowse",m=>"modmine",pc=>"machine");

sub new {
 my $class = shift;
 my %arg = @_;

 my $self = bless {dbstring => join(':','DBI:mysql',$database,$host,'3306'),
                   user     => $user,
                   password => $password,
                   db_fields=> \%db_fields,
                   subs     => {},
                   ids      => {},
		   reports  => {},
                   status   => {}},ref $class || $class;

 
}

# Function hash
my %queries = (
get_ALL => sub {
 warn "Request from Flex app";
 my $self = shift;
 my $dbh = DBI->connect($self->{dbstring},$self->{user},$self->{password},{RaiseError=>1, AutoCommit=>1});
 my $sth;

 $sth = "SELECT * FROM Submissions";
 $sth = $dbh->prepare($sth);
 $sth->execute or warn "Couldn't data for interface initialization";
 my $results = []; #{submission=>[]};

 while (my @row = $sth->fetchrow) {
   my $out = {
	id      => $row[0],
	lab     => $row[1],
	organism=> $row[2],
	stanza  => $row[3],
	#descr   =>$row[4],
	status  => {},
	reports => {}
     };
     foreach my $i (5..$#row) {
       if(!$row[$i] || $row[$i] eq 'NULL'){
         $out->{status}->{$sth->{NAME}[$i]} = [0];
         $out->{reports}->{$sth->{NAME}[$i]} = [""];
       }else{
         if ($i == $#row) {
          $out->{status}->{$sth->{NAME}[$i]} = $row[$i] eq 'OK' ? [1] : [3]; 
         } else {
 	  $out->{status}->{$sth->{NAME}[$i]} = $row[$i] eq 'OK' ? [2] : [4];
         }
          $out->{reports}->{$sth->{NAME}[$i]} = $row[$i] eq 'OK' ? [""] : [$row[$i]];
      }
     }
     push(@{$results},$out);
  }
  my $final = {submissions=>{submission=> $results}};
  print STDERR "Dumper:".Dumper($results) if DEBUG;
  $sth->finish;
  $dbh->disconnect;
  
  return $final;
 },
update_field => sub {
 my $self = shift;
 my($sub_id,$field,$record) = @_;
 if (!$sub_id || !$field || !$record){return undef;}

 my $report = ref($record) eq "HASH"  ? $record->{report} : $record;
 

 my $dbh = DBI->connect($self->{dbstring},$self->{user},$self->{password},{RaiseError=>1, AutoCommit=>1});
 my $sth;

 # The $report is OK, just erase the report and mark sub as ok
 if ($report =~/^OK$/i || ($report=~/^OK/i && $' eq $PCFLAG)) {
  $sth = "UPDATE Submissions SET $field = '$report' WHERE id = $sub_id";
  warn "Query is [ $sth ]" if DEBUG;

  $sth = $dbh->prepare($sth);
  $sth->execute or warn "Failed to update $field for submission $sub_id";
  $sth->finish;
  $dbh->disconnect;
 } else {
   
   $sth = "UPDATE Submissions SET $field = '$report' WHERE id = $sub_id";

   #warn "Query string is $sth";
   
   $sth = $dbh->prepare($sth);
   $sth->execute or warn "Couldn't update the record for $field, submission $sub_id";
   $sth->finish;
   $dbh->disconnect;
  }
 }
);


# Main query-processing dispatcher
sub query {
 my $self = shift @_;
 my $q    = shift @_;
 chomp($q);

 if ($queries{$q}) {
  return $queries{$q}->($self,@_);
 }
}

sub groups {
 my $self = shift;
 return $self->{subs} ? [keys %{$self->{subs}}] : undef;
}

sub subs {
 my $self = shift;
 my $pi   = shift;
 return $self->{subs}->{$pi} ? $self->{subs}->{$pi} : undef;
}

# Database subroutines

# Updating fields Need ll attempt to update without checking if the record exists
sub update_field {
 my $self = shift;
 my($sub_id,$field,$record) = @_;

 my $report = ref($record) eq "HASH"  ? $record->{report} : $record;
 print STDERR "Processing $sub_id with a record for field [$field] saying: $report\n" if DEBUG;
 my $dbh = DBI->connect($self->{dbstring},$self->{user},$self->{password},{RaiseError=>1, AutoCommit=>1});
 my($sth,$stm);

 my $ok;

 if (!$self->{db_fields}->{$field}) {
  print STDERR "Field [$field] is not recognized\n";
  $dbh->disconnect;
  return;
 }

 # The $report is OK, just erase the report and mark sub as ok
 if ($report =~/^OK$/i && $self->{db_fields}->{$field}) {
  print STDERR "Updating record for $sub_id\n" if DEBUG;
  $stm = "UPDATE Submissions SET ".$self->{db_fields}->{$field}." = 'OK' WHERE id = $sub_id";
  print STDERR "Statement: $stm\n" if DEBUG;
  eval($dbh->do($stm));
  
  if ($@) {print STDERR "Updating record with OK flag failed\n";}
  } else { 
  # The $report is an actual report, first check if there's a report already and if there is, append the text
  $stm = "SELECT ".$self->{db_fields}->{$field}." FROM Submissions WHERE id = $sub_id";
  warn "Query string is $stm" if DEBUG;
  $sth = $dbh->prepare($stm);
  $sth->execute or warn "Couldn't retrieve the reports for ".$self->{db_fields}->{$field}.", submission $sub_id";
   ROW:
   my @row = $sth->fetchrow;
   #print STDERR "Loading tag $row[0]\n";
   if ($row[0] && $row[0] ne 'NULL' && $field ne "pc") {
     $stm = $row[0] eq 'OK' ? "UPDATE Submissions SET ".$self->{db_fields}->{$field}." = '$report' WHERE id = $sub_id" : "UPDATE Submissions SET ".$self->{db_fields}->{$field}." = '".join(';',($row[0],$report))."' WHERE id = $sub_id";
   } elsif (!$row[0] || $row[0] eq 'NULL' || $field eq "pc") {
     $stm = "UPDATE Submissions SET ".$self->{db_fields}->{$field}." = '$report' WHERE id = $sub_id";
   }
   $sth->finish;
   #if ($stm !~/^UPDATE/) {
   # print STDERR "Something is wrong\n";
   #}
   warn "Query string is $stm" if DEBUG;
   eval($dbh->do($stm));
   print STDERR "There were some errors: ".$@ if $@;
   }

   $dbh->disconnect;
   return;
}



# Insert a new record when the first report passed
sub insert_new {
 my $self = shift @_;
 my $report;
 my($id,$field,$record,$db) = @_;
 if (!$id || !$record || ref($record) ne "HASH") {
  warn "Attempt to insert a record with no sufficient information";
  $db->disconnect if $db;
  return 0;
 } 

 if (!$db) {
  $db = DBI->connect($self->{dbstring},$self->{user},$self->{password},{RaiseError=>1, AutoCommit=>1});
 }

 if ($record->{lab} && $record->{org}) {
    $record->{stanza} ||='NA';
    $record->{descr}  ||='NA';

    my $ok = 1;
    my $stm = "INSERT INTO Submissions (id,lab,organism,stanza,descr) VALUES(".join(",",($id,"'".$record->{lab}."'","'".$record->{org}."'","'".$record->{stanza}."'","'".$record->{descr}."'")).")";
    print STDERR "Statement: $stm" if DEBUG;
    $db->do($stm) or $ok = 0;
    #if ($self->{db_fields}->{$field} && $record->{report} && $ok) {
    #  $db->do("UPDATE Submissions SET ".$self->{db_fields}->{$field}." = '".$record->{report}."'");
    #} 
   
 } else {
   warn "Not enough data passed, cannot create a record for submission [$id]";
   return 0;
 }
 $db->disconnect;
 return 1;
}

# Get ids of submission
sub get_ids {
 my %ids=();

 my $dbh = DBI->connect(join(':','DBI:mysql',$database,$host,'3306'),$user,$password,{RaiseError=>1, AutoCommit=>1});
 my($stm,$sth);

 $stm = "SELECT id FROM Submissions";
 $sth = $dbh->prepare($stm);
 $sth->execute or warn "Couldn't get ids of submissions in the database";

 if ($@) {
  print STDERR "Error getting ids from database: [$@]\n";
  $dbh->disconnect;
  return undef;
 }

 while(my @row = $sth->fetchrow) {
  next if !$row[0];

  chomp($row[0]);
  if ($row[0]=~/^\d+$/) {
   $ids{$row[0]}++;
  }
 }
 
 $sth->finish;
 $dbh->disconnect;
 return \%ids;
}

# Sub for cleaning up the database will delete submissions passed to it
sub cleanup {
 my $self  = shift @_;
 my %deletes = ();
 map{$deletes{$_}++} @{shift @_};
 if (!%deletes || scalar(keys %deletes) == 0) {
  return; # do nothing
 }

 my $dbh = DBI->connect($self->{dbstring},$self->{user},$self->{password},{RaiseError=>1, AutoCommit=>1});

 map{$dbh->do("DELETE FROM Submissions WHERE id = ".$_)} (keys %deletes);
 $dbh->disconnect;
}

# Initialization of the interface

sub get_data {
 my $self = shift @_;
 my $dbh = DBI->connect($self->{dbstring},$self->{user},$self->{password},{RaiseError=>1, AutoCommit=>1});
 my($stm,$sth);

 $stm = "SELECT * FROM Submissions";
 $sth = $dbh->prepare($stm);
 $sth->execute or warn "Couldn't get data for interface initialization";


 while (my @row = $sth->fetchrow) {
    if ($self->{subs}->{$row[1]}) {push(@{$self->{subs}->{$row[1]}},$row[0]);}else{$self->{subs}->{$row[1]} = [$row[0]];}
    $self->{ids}->{$row[0]} = {lab=>$row[3],org=>$row[2],stanza=>$row[3],desc=>$row[4]};
    foreach my $i (5..$#row) {
      if(!$row[$i] || $row[$i] eq 'NULL'){
        $self->{status}->{$row[0]}->{$sth->{NAME}[$i]} = 0;
      }else{
        $self->{status}->{$row[0]}->{$sth->{NAME}[$i]} = $row[$i] eq 'OK' ? 1 : 2;
      }
    }
 }
 $sth->finish;
 $dbh->disconnect;

 warn "Initialization complete";
}

# Get report(s)

sub get_reports {
 my($sub_id,$field) = @_;
 
 my $dbh = DBI->connect(join(':','DBI:mysql',$database,$host,'3306'),$user,$password,{RaiseError=>1, AutoCommit=>1});
 my($stm,$sth);
 
 $stm = $field ? "SELECT $db_fields{$field} FROM Submissions WHERE id = $sub_id" : "SELECT * FROM Submissions WHERE id = $sub_id";
 $sth = $dbh->prepare($stm);
 $sth->execute or warn "Couldn't get reports for submission $sub_id";

 my @reports = ();

 my @row = $sth->fetchrow; 
 my $start = @row > 5 ? 5 : 0;
 map{if ($row[$_] && $row[$_] ne 'OK' && $row[$_] ne 'NULL'){push (@reports,$row[$_])}} ($start..$#row);
 $sth->finish;
 $dbh->disconnect;

 if ($field) {return $reports[0] =~ /\w+/ ? $reports[0] : undef;}
 return @reports > 0 ? join(";",@reports) : "There are no records for this submission"; 
}


