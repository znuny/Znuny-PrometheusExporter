# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::PrometheusExporter::Stop;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::SysConfig',
);

=head1 NAME

Kernel::System::Console::Command::Admin::PrometheusExporter::Stop - Disable and stop the Prometheus Exporter

=head1 DESCRIPTION

Disables the C<DaemonModules###PrometheusExporter> SysConfig setting, deploys
the configuration, and restarts the Znuny Daemon so the exporter stops
accepting scrape requests.

=cut

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Disable the Prometheus Exporter daemon module and restart the Znuny Daemon.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

    # ------------------------------------------------------------------
    # 1. Disable the daemon module via SysConfig
    # ------------------------------------------------------------------
    $Self->Print("<yellow>Disabling SysConfig setting DaemonModules###PrometheusExporter...</yellow>\n");

    my %Setting = $SysConfigObject->SettingGet(
        Name => 'DaemonModules###PrometheusExporter',
    );

    if ( !%Setting ) {
        $Self->PrintError("SysConfig setting 'DaemonModules###PrometheusExporter' not found.\n");
        $Self->PrintError("Make sure the Znuny-PrometheusExporter package is installed correctly.\n");
        return $Self->ExitCodeError();
    }

    my $Success = $SysConfigObject->SettingUpdate(
        Name           => 'DaemonModules###PrometheusExporter',
        IsValid        => 0,
        EffectiveValue => $Setting{EffectiveValue},
        UserID         => 1,
    );

    if ( !$Success ) {
        $Self->PrintError("Could not disable the SysConfig setting.\n");
        return $Self->ExitCodeError();
    }

    # ------------------------------------------------------------------
    # 2. Deploy the configuration
    # ------------------------------------------------------------------
    $Self->Print("<yellow>Deploying configuration...</yellow>\n");

    $SysConfigObject->ConfigurationDeploy(
        Comments => 'Disabled by Admin::PrometheusExporter::Stop',
        UserID   => 1,
        Force    => 1,
    );

    # ------------------------------------------------------------------
    # 3. Restart the Znuny Daemon
    # ------------------------------------------------------------------
    my $Home         = $ConfigObject->Get('Home');
    my $DaemonScript = "$Home/bin/znuny.Daemon.pl";

    if ( -x $DaemonScript ) {
        $Self->Print("<yellow>Restarting Znuny Daemon...</yellow>\n");
        system("$DaemonScript restart 2>&1");
    }
    else {
        $Self->Print(
            "<yellow>Daemon script not found at $DaemonScript.\n"
                . "Please restart the Znuny Daemon manually:\n"
                . "  bin/znuny.Daemon.pl restart</yellow>\n"
        );
    }

    $Self->Print("<green>Prometheus Exporter has been disabled.</green>\n");
    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

1;
