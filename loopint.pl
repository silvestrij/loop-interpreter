#!/usr/bin/perl -w
use strict;

#March/April 2005 - John B. Silvestri
#loopint.pl - an interpreter for Stathis Zachos' loop language
#n.b. Superseded by loopint4.pl

###########
# GLOBALS #
###########

my %variables;

my $value_qr=qr/(^\d*$)/; #Just digits
my $var_qr=qr/(^\w\d*$)/; #Single character, followed by zero or more digits
my $op_qr=qr/(\.-|\+|succ|pred)/; #Match ops

###############
# LINEAR CODE #
###############

my @input_block;

if(@ARGV){
	my $input_file=shift;
	open LOOPFILE, "<", $input_file
		or die "Could not open source file: $!\n";
	chomp (@input_block=<LOOPFILE>);
}else{ 
	print "Enter a loop program, terminated with a newline and ^d\n";
	chomp(@input_block=<STDIN>);
}

my $maincode=join (" ", @input_block);
code_eval($maincode);


###############
# Memory Dump #
###############

print "-"x40 . "\nVariables\n" . "-"x40 ."\n";
foreach (sort keys %variables){
	print "$_ = $variables{$_}\n";
}

###############
# SUBROUTINES #
###############

sub code_eval{
	my $code=shift;
	my $codelen=length($code);
	my ($start,$stop,$pos)=(0,0,0);
	
	while ($start < $codelen){
	
		my $assign_pos=index($code,":=",$start);
		my $for_pos=index($code,"for",$start);
	
		if (first_pos($assign_pos, $for_pos)){ #if 0 < = assign_pos < = for_pos
			my $semi_index=index($code,";",$start); #Find proper end of statement
			$stop=$semi_index > 0 ? $semi_index : $codelen -1; #Set bounds (works w/o final ';')

			my $assign_stmt=substr($code, $start,$stop-$start); #Get assignment statement
			assign_eval($assign_stmt); #Evaluate the assignment, setting variable's value

			$start=$stop+1; #Increment starting position for substring searching
		}elsif(first_pos($for_pos, $assign_pos)){ #if 0 < = for_pos < = assign_pos
			#Aaaaaaaaaahhhh....save us all, it's recursion city!
			#Okay, logically - it can't be that bad
			#A for loop in LOOP consists of:
			#
			#for [interator]:=[var/val] to [var/val] do [statement(s)] end
			#
			#Therefore, the parse goes as follows:
			#Read the parts up until 'do' - these are all simple
			#Do the iterator assignment, and set a lock on the variable in an %iterator hash
			#Get the bounds lined up, calling part_eval on the RHS of "to [var/val]"
			#Then, the hell begins
			#A subroutine probably needs to be written, find_end, which finds the end of the
			#statement(s) contained in the for loop.  Doing this will look for nested for
			#loops - if a "for" is found, recursively call find_end.
			#Once the end is found, store code block in a variable, and iterate over bounds,
			#doing a code_eval each time.  (This will in turn do recursion on interior for loops)

#Picture time
#
#  /$for_pos       /$do_pos
# /    $for_pos+3 /  $do_pos+2
# /   /$iter_pos /  /$code_pos
# |  |          /  /
# |  |       vvv| |
# for i:=1 to e do lalallal for blah end lallllllallala end
#    ^^^^^^| |    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^| |
#          | \$bound_pos                       $code_end/ |
#          |  $to_pos+2                       find_end()  /
#          \$to_pos                                      /
#                                                  $stop/
#                                            $code_end+2  
#
# String bounds:
# Iterator assignment: $iter_pos, len=$to_pos - $iter_pos
# Bound: $bound_pos, len = $do_pos - $bound_pos
			my $iter_pos=$for_pos+3;
			my $to_pos=index($code, "to",$iter_pos);
			my $bound_pos=$to_pos+2;
			my $do_pos=index($code, "do",$bound_pos);
			my $code_pos=$do_pos+2;

			my $iter_assign=substr($code, $iter_pos, $to_pos - $iter_pos);
			my $boundary=substr($code, $bound_pos, $do_pos - $bound_pos);

			print "assign|$iter_assign;boundary:$boundary;\n";
			
			#my $end_pos=find_end....#magic hocus-pocus
			exit(0);
		}else{
			print "Invalid Input\n";
			exit(1);
		}
	
	} #end while loop
} #end sub code_eval

sub assign_eval{
	my $assign_stmt=shift;
	my @assign_parts=split(":=",$assign_stmt);
	my ($a_lhs,$a_rhs)=@assign_parts;
	$a_lhs=~s/\s//g; #strip whitespace
	if ($a_rhs=~/$op_qr/){
		$variables{$a_lhs}=st_eval($a_rhs);
	}else{
		$variables{$a_lhs}=part_eval($a_rhs);
	}
}

sub st_eval{
	my $stmt=shift;
	my @parts=split(/$op_qr/, $stmt);
	$stmt=~m/$op_qr/; #Capture op to $1
	my $op=$1;
	if($op eq ".-"){
		my($lhs,$rhs)=@parts[0,2];
		my $val1=part_eval($lhs);
		my $val2=part_eval($rhs);
		my $result=($val1 >= $val2) ? $val1-$val2 : 0;
		return $result;
	}elsif($op eq "+"){
		my($lhs,$rhs)=@parts[0,2];
		my $val1=part_eval($lhs);
		my $val2=part_eval($rhs);
		my $result=$val1+$val2;
		return $result;
	}elsif($op eq "succ"){
		my $rhs=$parts[2];
		my $val1=part_eval($rhs);
		my $result=$val1+1;
		return $result;
	}elsif($op eq "pred"){
		my $rhs=$parts[2];
		my $val1=part_eval($rhs);
		my $result=($val1 >= 0) ? $val1-1 : 0;
		return $result;
	}
} #end sub st_eval

sub part_eval{
	my $part=shift;
	$part =~ s/\s//g; #Strip whitespace
	if ($part=~m/$value_qr/){
		my $value=$1;
		return $value;
	}elsif($part=~m/$var_qr/){
		my $varname=$1;
		if (exists $variables{$varname}){
			return $variables{$varname};
		}else{
			die "Variable $varname has not been initialized\n";
		}
	}
} #end sub part_eval

sub first_pos{
	my ($a_in,$b_in)=@_; #given a and b, return boolean of which comes first (and is >=0)
	#if 0 < = a_in < = b_in
	if ($a_in == -1){ #if "a" isn't there -> definitely not it
		return 0;
	}elsif ($b_in == -1){ #'b' isn't there -> 'a' wins handsdown (exists, and must be greater)
		return 1;
	}elsif ($a_in < $b_in){ #'a' really comes before 'b'
		return 1;
	}else{ # 'b' came first
		return 0;
	}
}
