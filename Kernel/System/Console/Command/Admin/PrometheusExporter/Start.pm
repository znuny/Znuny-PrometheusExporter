# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::PrometheusExporter::Start;

use strict;
use warnings;
use utf8;

use parent qw(Kernel::System::Console::BaseCommand);

use IO::Socket::INET;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::SysConfig',
);

=head1 NAME

Kernel::System::Console::Command::Admin::PrometheusExporter::Start - Enable and start the Prometheus Exporter

=head1 DESCRIPTION

Enables the C<DaemonModules###PrometheusExporter> SysConfig setting, deploys
the configuration, and restarts the Znuny Daemon so the exporter begins
listening for Prometheus scrape requests.

=cut

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Enable the Prometheus Exporter daemon module and restart the Znuny Daemon.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

    # ------------------------------------------------------------------
    # 1. Enable the daemon module via SysConfig
    # ------------------------------------------------------------------
    $Self->Print("<yellow>Enabling SysConfig setting DaemonModules###PrometheusExporter...</yellow>\n");

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
        IsValid        => 1,
        EffectiveValue => $Setting{EffectiveValue},
        UserID         => 1,
    );

    if ( !$Success ) {
        $Self->PrintError("Could not enable the SysConfig setting.\n");
        return $Self->ExitCodeError();
    }

    # ------------------------------------------------------------------
    # 2. Deploy the configuration
    # ------------------------------------------------------------------
    $Self->Print("<yellow>Deploying configuration...</yellow>\n");

    $SysConfigObject->ConfigurationDeploy(
        Comments => 'Enabled by Admin::PrometheusExporter::Start',
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
        sleep 3;
    }
    else {
        $Self->Print(
            "<yellow>Daemon script not found at $DaemonScript.\n"
                . "Please restart the Znuny Daemon manually:\n"
                . "  bin/znuny.Daemon.pl restart</yellow>\n"
        );
    }

    # ------------------------------------------------------------------
    # 4. Verify the exporter is listening
    # ------------------------------------------------------------------
    my $Port = $ConfigObject->Get('Daemon::PrometheusExporter::Port') || 9405;
    my $Bind = $ConfigObject->Get('Daemon::PrometheusExporter::Bind') || '127.0.0.1';

    # Use 127.0.0.1 for the connectivity check even when bound to 0.0.0.0
    my $CheckAddr = $Bind eq '0.0.0.0' ? '127.0.0.1' : $Bind;

    my $Socket = IO::Socket::INET->new(
        PeerAddr => $CheckAddr,
        PeerPort => $Port,
        Proto    => 'tcp',
        Timeout  => 3,
    );

    if ($Socket) {
        close($Socket);
        $Self->Print("<green>Prometheus Exporter is listening on $Bind:$Port.</green>\n");
    }
    else {
        $Self->Print(
            "<yellow>Could not connect to $CheckAddr:$Port yet.\n"
                . "The daemon may need a few more seconds to start.\n"
                . "Check 'bin/znuny.Daemon.pl status' for details.</yellow>\n"
        );
    }

    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

1;
