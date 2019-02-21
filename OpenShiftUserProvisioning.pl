#!/usr/bin/perl

#
# Ministry of Attorney General / Ministry of Public Safety and Solicitor General
# ISB
# Ryan Loiselle - 2503808656
# February 2019
#

#
# PERL INCLUDES
#

use Log::Handler;
use Spreadsheet::ParseXLSX;
use POSIX qw/strftime/;
use Switch;

#
# VARIABLES
#

our $parserXLSX = Spreadsheet::ParseXLSX->new;
our $OpenShiftRBAC;
our $OpenShiftRBACName;
our $OpenShiftRBACAbsolute;
our $RBACScriptName;
our $RBACScript;
our $RBACScriptLookup;
our $RulesFilesLookup;
our $LogFile;
our $Rows;
our $Columns;

##############
#
# START MAIN
#
 
# PRE-PROCESSING TASKS - INTERACT WITH USER, FETCH INITIAL DATA
print("-> starting pre_processing \n");
pre_processing();
print("-> pre_processing complete \n\n");

# LOAD OPEN SHIFT RBAC MATRIX XLSX AS REQUESTED
print("-> load_OpenShiftRBAC starting \n");
load_OpenShiftRBAC( $OpenShiftRBACAbsolute, $parserXLSX );
print("-> load_OpenShiftRBAC completed \n\n");

# GENERATE OPENSHIFT RBAC PROVISIONING SCRIPTS 
print("-> rbac_generator starting \n");
rbac_generator();
print("-> rbac_generator complete \n\n");

############### TO DO: ###############
##
## EXTEND LOGGING
##
######################################

# POST-PROCESSING TASKS
post_processing();

#
# END MAIN
##############

 

#
### SUBROUTINES ###
#


# SUB: PRE PROCESSING
sub pre_processing {
 

        # PROMPT FOR INPUT FROM USER - EVENTUALLY FORM DATA WHEN ENTERING INFO INTO/FROM DB
        print "\n--> Enter the name of the OpenShiftRBAC Matrix to be processed from /Users/rloisell/Documents/scripts/perl/OpenShift_provisioning/ :\n<-- ";
        chomp( $OpenShiftRBACName = <STDIN> );

        # PROMPT FOR RULES NAME, SHOULD BE CONSISTENT WITH BASE RULES EXPORTED FROM MIB MGR
        print "\n--> Enter the Project name for this OpenShiftRBAC matrix (NOTE - no spaces, this input generates file names): \n<-- ";
        chomp( $RBACScriptName = <STDIN> );

        # FILES NAMES BASED ON USER INPUT
        $OpenShiftRBACAbsolute = "/Users/rloisell/Documents/scripts/perl/OpenShift_provisioning/$OpenShiftRBACName";
        $RBACScriptAddUsers = "$RBACScriptName.AddUserRBAC.sh";
        $RBACScriptDeleteUsers = "$RBACScriptName.DeleteUserRBAC.sh";
        $LogFile = "$RBACScriptName.OpenShiftUserProvisioning.log";
 
        # OPEN FILES REQUIRED FOR LOGGING, OUTPUT, ETC
        open ( $RBACScriptAddUsers, ">>output/$RBACScriptAddUsers" ) or die qq {"Cannot open $RBACScriptAddUsers for writing: $!"};
        open ( $RBACScriptDeleteUsers, ">>output/$RBACScriptDeleteUsers" ) or die qq {"Cannot open $RBACScriptDeleteUsers for writing: $!"};
        open ( $LogFile, ">>logs/$LogFile" ) or die qq {"Cannot open $LogFile for writing: $!"};
 
        # DEBUGGING:
        # **TODO: MASK IF DEBUG TURNED OFF**
        print "\n<--  INPUT: OpenShift RBAC Matrix Name: $OpenShiftRBACName \n";
        print "<--  INPUT: Absolute Path: $OpenShiftRBACAbsolute \n";
        print "--> OUTPUT: OpenShift RBAC Add Users script: $RBACScriptAddUser \n";
        print "--> OUTPUT: OpenShift RBAC Delete Users script: $RBACScriptDeleteUsers \n";
        print "--> OUTPUT: Log File for this session: $LogFile \n\n";
 
        # LOGGING
        my $runTime = strftime("%Y-%m-%d", localtime);
        printf $LogFile qq{\nOpenShiftUserProvisioning.pl run on $runTime: \n\n};
        printf $LogFile qq{<--  INPUT: OpenShift RBAC Matrix Name: $OpenShiftRBACName \n};
        printf $LogFile qq{--> OUTPUT: OpenShift RBAC Add Users script: $RBACScriptAddUsers \n};
        printf $LogFile qq{--> OUTPUT: OpenShift RBAC Delete Users script: $RBACScriptDeleteUsers \n};
        printf $LogFile qq{--> OUTPUT: Log File for this session: $LogFile \n\n};

}
# END SUB: PRE PROCESSING
 

# SUB: LOAD OPENSHIFT RBAC MATRIX
sub load_OpenShiftRBAC {

        # ASSIGN PASSED VARIABLE TO LOCAL VARIABLE
        my ( $aOpenShiftRBACAbsolute ) = $_[0];
        my ( $aParserXLSX ) = $_[1];

        # INSTANTIATE NEW OBJECT WITH PARSED DATA FROM DESIRED FILE
        $OpenShiftRBAC = $aParserXLSX ->parse( "$aOpenShiftRBACAbsolute" );
        if ( !defined $OpenShiftRBAC ) {
                die $aParserXLSX->error(), ".\n";
        }

        # DEBUGGING
        print "--> load_OpenShiftRBAC() asked to parse $aOpenShiftRBACAbsolute \n";

        # LOGGING
        printf $LogFile qq{--> load_OpenShiftRBAC() asked to parse $aOpenShiftRBACAbsolute, data loaded: };
        printf $LogFile qq{\n\n};
        for my $worksheet ( $OpenShiftRBAC->worksheets() ) {

               my ( $row_min, $row_max ) = $worksheet->row_range();
               my ( $col_min, $col_max ) = $worksheet->col_range();

               for my $row ( $row_min .. $row_max ) {
                       for my $col ( $col_min .. $col_max ) {

                               my $cell = $worksheet->get_cell( $row, $col );
                               next unless $cell;

                               my $value = $cell->value();
                               my $unformatted = $cell->unformatted();

                               printf $LogFile "--> Row, Col    = ($row, $col)\n";
                               printf $LogFile "--> Value       = $value       \n";
                               printf $LogFile "--> Unformatted = $unformatted \n";
                               printf $LogFile "\n";
                       }
               }
        }
}

 

# SUB: RBAC GENERATOR
sub rbac_generator {

        # FOR XLSX DATASHEET (Sheet 0)
        for my $worksheet ( $OpenShiftRBAC->worksheet(0) ) {

                my ( $row_min, $row_max ) = $worksheet->row_range();
                my ( $col_min, $col_max ) = $worksheet->col_range();
                print"--> rbac_generator: row_max: $row_max \n";

                # CREATE SHELL SCRIPT 
                printf $RBACScriptAddUsers qq{#!/bin/bash\n};
				printf $RBACScriptDeleteUsers qq{#!/bin/bash\n};

                # FOR EACH ROW IN THE OpenShift RBAC Matrix (A USER RABC PER PROJECT SPACE))
                for my $row ( 1 .. $row_max ) {

                        #
                        # FOR EACH ROW IN THE XLS FILE, WRITE DESIRED VALUES TO OUTPUT FILES
                        # THESE ARE THE VALUES FOR $RBACScript
                        #

						# PROJECT
						my $PROJECT = $worksheet->get_cell( $row, 0 );
						next unless $PROJECT;
						$PROJECT = $worksheet->get_cell( $row, 0 )->value();
						print "---> rbac_generator: OpenShift Project: $PROJECT \n";
			
						# GITHUB ID
						my $GITHUBID = $worksheet->get_cell( $row, 1 );
						next unless $GITHUBID;
						$GITHUBID = $worksheet->get_cell( $row, 1 )->value();
						# print "---> rbac_generator: HAS A GITHUB ID \n"; 
			
						# OPEN SHIFT ROLE
						my $OCPROLE = $worksheet->get_cell( $row, 2 );
						next unless $OCPROLE;
						$OCPROLE = lc $worksheet->get_cell( $row, 2 )->value();
						# print "---> rbac_generator: HAS AN OCP ROLE \n"; 
			
						# JUSTIFICATION
						my $JUSTIFICATION = $worksheet->get_cell( $row, 3 );
						next unless $JUSTIFICATION;
						$JUSTIFICATION = $worksheet->get_cell( $row, 3 )->value();
						# print "---> rbac_generator: HAS A JUSTIFICATIONO \n";

                        # COMMENTS
                        my $COMMENTS = $worksheet->get_cell( $row, 4 );
                        next unless $COMMENTS;
                        $COMMENTS = $worksheet->get_cell( $row, 4 )->value();
						# print "---> rbac_generator: HAS COMMENTS \n";
						
						# DISPLAY TO USER 
						# print "----> rbac_generator: ENTERING CASE SWITCH WITH GitHub ID - $GITHUBID, OpenShift Role - $OCPROLE, Justification: $JUSTIFICATION \n";
						
						# SWITCH TO OCP ROLE FOR 
						switch ($OCPROLE) {
							
							# ADMIN ROLE
							case "admin" { 
								print "-----> rbac_generator: $OCPROLE role\n";
								printf $RBACScriptAddUsers qq{oc policy add-role-to-user admin $GITHUBID -n $PROJECT\n};
								printf $LogFile qq{ \n};
							}
							# EDIT ROLE
							case "edit" {
								print "-----> rbac_generator: $OCPROLE role\n";
								printf $RBACScriptAddUsers qq{oc policy add-role-to-user edit $GITHUBID -n $PROJECT\n};
								printf $LogFile qq{ \n};
							}
							# VIEW ROLE
							case "view" {
								print "-----> rbac_generator: $OCPROLE role\n";
								printf $RBACScriptAddUsers qq{oc policy add-role-to-user view $GITHUBID -n $PROJECT\n};
								printf $LogFile qq{ \n};
							}
							else {
								print "-----> rbac_generator: error - invalid role specified: $OCPROLE\n";
								printf $LogFile qq{-----> rbac_generator: error - invalid role specified: $OCPROLE\n};
							}
							
						}
						# END SWITCH $OCPROLE
						
						# DELETE USERS SCRIPT
						printf $RBACScriptDeleteUsers qq{oc project $PROJECT\n};
						printf $RBACScriptDeleteUsers qq{oc policy remove-user $GITHUBID\n\n};						
						

                } 
				# END FOR MY ROW
        }
		# END FOR MY WORK SHEET
}
# END SUB: RBAC GENERATOR


# SUB: POST PROCESSING
sub post_processing {

        # CLOSE OPEN FILES
        close $RBACScriptAddUsers;
        close $RBACScriptDeleteUsers;
        close $LogFile;

}
# END SUB: POST PROCESSING
