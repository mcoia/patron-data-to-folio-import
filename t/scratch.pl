#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

my @files = (
    'eccpat.txt',
    'jcpat.txt',
    'MACStummddyy.txt',
    'MACStaffmmddyy.txt',
    'MACAdjunctmmddyy.txt',
    'SCCstudent',
    'SCCstaff',
    'SLCCStudent',
    'SLCCStaff',
    'TRCstuyyyymmdd',
    'TRCstaffyyyymmdd',
    'stlcoppat.txt',
    'COLUMBIA_PATRONS',
    'LUPAT.Dyymdd',
    'n/a',
    'scstudent',
    'wcstudents.txt',
    'WWUpatrons.txt',
    'WWUbarcodesUG.txt',
    'ATSU_mmddyyyy.txt',
    'CMUstuyyyymmdd.out',
    'CMUgryyyymmdd.out',
    'CMUfacyyyymmdd.out',
    'csctmmddyyyy.txt',
    'HLG-STUDENTS',
    'MVC_Student_Updates_mm_dd.txt',
    'MACCPatLoadmm-dd-yy',
    'SFCC_Student_mmddyy.txt',
    'SFCC_Staff_mmddyy.txt',
    'STC_yyyy-mm-dd',
    'tpbstupat',
    'cslpatrons.txt',
    'covstu.txt',
    'covfac.txt',
    'FCstuPAT.DAT',
    'FCfacPAT.DAT',
    'HSSUyymmdd.txt',
    'n/a',
    'LUSTUPAT.txt',
    'LUFACPAT.txt',
    'loganstu.txt',
    'mustupat.dyymmdd.txt',
    'mustapat.dyymmdd.txt',
    'mufacpat.dyymmdd.txt',
    'muadjpat.dyymmdd.txt',
    'mobapstu.txt',
    'EWLPat.txt',
    'n/a',
    'n/a',
    'n/a',
    'n/a',
    'Avila_Upload_mm-dd-yy',
    'bcpatrons.txt',
    'n/a',
    'n/a',
    'KCAI_PATRON_LOAD_mmyyyy',
    'KCKCC_LIB_STU.txt',
    'KCKCC_LIB_EMP.txt',
    'KCU-yyyy-mm-dd.txt',
    'mccstuMMYY.txt',
    'mccfacMMYY.txt',
    'mbtsstu.dyymmdd.txt',
    'mwsuugr.txt',
    'mwsugr.txt',
    'mwsufac.txt',
    'mwsuexp.txt',
    'mwsuadj.txt',
    'mwsuinst.txt',
    'mwsuwdraw.txt',
    'nts_patrons.txt',
    'ncmcstu.txt',
    'nwmsustu.txt',
    'nwmsuempl.txt',
    'parkstufac.txt',
    'RKRST_Stu_mm-dd-yyyy.txt',
    'RKRST_Staff_mm-dd-yyyy.txt',
    'RKRST_Faculty_mm-dd-yyyy.txt',
    'n/a',
    'WJC_MOBIUS_STUDENTS.txt',
    'COTTyyyymmdd.txt',
    'ccstupat.txt',
    'DRURYPAT_students.txt',
    'DRURYPAT_employees.txt',
    'DRURYPAT_alumni.txt',
    'EUPatronCamsExport_month_day_year',
    'MSSCALL',
    'MobiusUploadyyyydd.txt',
    'otcpat.txt',
    'SBUPATRONS',
    'patronLoad.marc');

for my $file (@files)
{
    next if ($file =~ 'n/a');

    print "---------------------------------\n";
    print $file . "\n";

    my $extension = ($file =~ /\.\w*$/g)[0];
    $extension = "" if (!defined($extension));

    print "extension: [$extension]\n" if (defined($extension));

    $file =~ s/dd.*/*/g;
    $file =~ s/mm.*/*/g;
    $file =~ s/yy.*/*/g;

    $file =~ s/DD.*/*/g;
    $file =~ s/MM.*/*/g;
    $file =~ s/YY.*/*/g;

    $file =~ s/month.*/*/g;
    $file =~ s/day.*/*/g;
    $file =~ s/year.*/*/g;

    # add the file extension back if it isn't already and we have one.
    $file .= $extension if ($file !~ /$extension/ && $extension ne '');

    print $file . "\n";

}

# my $command = "find $institution->{'folder'}->{'path'}/* -iname $file->{pattern}*";
