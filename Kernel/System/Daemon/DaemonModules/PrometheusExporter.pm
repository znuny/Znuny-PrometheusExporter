# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Daemon::DaemonModules::PrometheusExporter;

use strict;
use warnings;
use utf8;

use IO::Socket::INET;
use Time::HiRes qw(time);

use parent qw(Kernel::System::Daemon::BaseDaemon);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DateTime',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Queue',
    'Kernel::System::State',
    'Kernel::System::Type',
    'Kernel::System::Service',
    'Kernel::System::User',
    'Kernel::System::AuthSession',
);

=head1 NAME

Kernel::System::Daemon::DaemonModules::PrometheusExporter - Prometheus metrics exporter daemon module

=head1 DESCRIPTION

Exposes a Prometheus-compatible C</metrics> HTTP endpoint from within the
Znuny Daemon process.  No separate script or service unit is required.

Configuration via SysConfig:

=over 4

=item C<Daemon::PrometheusExporter::Port> (default: 9405)

=item C<Daemon::PrometheusExporter::Bind> (default: 127.0.0.1)

=back

=head1 PUBLIC INTERFACE

=head2 new()

Create a new exporter daemon module object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless $Self, $Type;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{Port} = $ConfigObject->Get('Daemon::PrometheusExporter::Port') || 9405;
    $Self->{Bind} = $ConfigObject->Get('Daemon::PrometheusExporter::Bind') || '127.0.0.1';

    # Optional feature flags — checked once at startup.
    $Self->{ServiceEnabled} = $ConfigObject->Get('Ticket::Service') ? 1 : 0;
    $Self->{TypeEnabled}    = $ConfigObject->Get('Ticket::Type')    ? 1 : 0;

    # Sleep 1 second between Run() cycles; keeps the loop responsive
    # without busy-waiting.
    $Self->{SleepPost} = 1;

    # Restart the module every hour so the object manager stays fresh.
    $Self->{Discard}      = 60 * 60;
    $Self->{DiscardCount} = $Self->{Discard} / $Self->{SleepPost};

    $Self->{Debug}      = $Param{Debug};
    $Self->{DaemonName} = 'Daemon: PrometheusExporter';

    return $Self;
}

=head2 PreRun()

Open the TCP server socket.  Called once before the first C<Run()>.
Returns false if the database is not reachable or the socket cannot be bound.

=cut

sub PreRun {
    my ( $Self, %Param ) = @_;

    # Socket already open from a previous iteration — nothing to do.
    return 1 if $Self->{ServerSocket};

    # Open a non-blocking server socket so Run() can call accept() without
    # stalling the Daemon loop.
    #
    # Retry up to 10 times (20 s total) to handle the race condition that
    # occurs when the daemon discards and restarts this module: the old
    # subprocess may still hold the port open for a brief moment even
    # though ReuseAddr is set.
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MaxRetries = 10;
    ATTEMPT:
    for my $Attempt ( 1 .. $MaxRetries ) {
        $Self->{ServerSocket} = IO::Socket::INET->new(
            LocalAddr => $Self->{Bind},
            LocalPort => $Self->{Port},
            Proto     => 'tcp',
            Listen    => 10,
            ReuseAddr => 1,
            Blocking  => 0,
        );
        last ATTEMPT if $Self->{ServerSocket};
        sleep 2      if $Attempt < $MaxRetries;
    }

    if ( !$Self->{ServerSocket} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "PrometheusExporter: Cannot bind to $Self->{Bind}:$Self->{Port} - $!",
        );
        return;
    }

    $LogObject->Log(
        Priority => 'notice',
        Message  => "PrometheusExporter: Listening on $Self->{Bind}:$Self->{Port}",
    );

    return 1;
}

=head2 Run()

Accept one pending HTTP connection (non-blocking) and serve it.
Called repeatedly by the Daemon; must return quickly.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    return 1 if !$Self->{ServerSocket};

    # Non-blocking accept — returns undef immediately if no connection is waiting.
    my $Client = $Self->{ServerSocket}->accept();
    return 1 if !$Client;

    $Client->blocking(1);    # switch client socket to blocking for reading/writing

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    eval { $Self->_HandleRequest($Client) };
    if ($@) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "PrometheusExporter: Request handler error - $@",
        );
    }

    close($Client);

    return 1;
}

=head2 PostRun()

Sleep between cycles and manage the discard/restart counter.
Returning false signals the Daemon to discard and restart this module.

=cut

sub PostRun {
    my ( $Self, %Param ) = @_;

    sleep $Self->{SleepPost};

    $Self->{DiscardCount}--;

    if ( $Self->{DiscardCount} <= 0 ) {
        if ( $Self->{Debug} ) {
            print "  $Self->{DaemonName} will be stopped and set for restart!\n";
        }

        # Close the socket before signalling a restart so the port is
        # immediately available when the new instance calls PreRun().
        # Without this, DESTROY may run after the new PreRun() attempts
        # to bind, causing "Address already in use".
        if ( $Self->{ServerSocket} ) {
            close( $Self->{ServerSocket} );
            delete $Self->{ServerSocket};
        }

        return;
    }

    return 1;
}

=head2 Summary()

Return status information shown by C<bin/znuny.Daemon.pl status>.

=cut

sub Summary {
    my ( $Self, %Param ) = @_;

    return (
        {
            Header => 'Prometheus Exporter',
            Column => [
                {
                    Name        => 'Attribute',
                    DisplayName => 'Attribute',
                    Size        => 20
                },
                {
                    Name        => 'Value',
                    DisplayName => 'Value',
                    Size        => 40
                },
            ],
            Data => [
                {
                    Attribute => 'Bind',
                    Value     => $Self->{Bind}
                },
                {
                    Attribute => 'Port',
                    Value     => $Self->{Port}
                },
                {
                    Attribute => 'Status',
                    Value     => $Self->{ServerSocket} ? 'Listening' : 'Stopped'
                },
            ],
            NoDataMessage => 'No information available.',
        },
    );
}

sub DESTROY {
    my $Self = shift;

    if ( $Self->{ServerSocket} ) {
        close( $Self->{ServerSocket} );
    }

    return 1;
}

# ===========================================================================
# PRIVATE METHODS
# ===========================================================================

sub _HandleRequest {
    my ( $Self, $Client ) = @_;

    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $RequestLine = <$Client> // return;
    chomp $RequestLine;

    # Drain remaining HTTP headers.
    LAST: while ( my $Line = <$Client> ) {
        last LAST if $Line =~ m{^\r?\n$};
    }

    my ( undef, $Path ) = $RequestLine =~ m{^([A-Z]+)\s+(\S+)};
    $Path //= '/';

    if ( $Path eq '/metrics' ) {
        my $T0 = time();
        my ( $Body, $Success ) = eval { $Self->_CollectMetrics() };
        if ($@) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "PrometheusExporter: Metric collection failed - $@",
            );
            $Body    = '';
            $Success = 0;
        }

        my $Duration = time() - $T0;
        $Body .= _GaugeBlock(
            Name  => 'znuny_scrape_duration_seconds',
            Help  => 'Time taken to collect Znuny metrics (seconds)',
            Lines => ["znuny_scrape_duration_seconds $Duration"],
        );
        $Body .= _GaugeBlock(
            Name  => 'znuny_scrape_success',
            Help  => '1 if the last metric collection succeeded, 0 otherwise',
            Lines => [ 'znuny_scrape_success ' . ( $Success ? 1 : 0 ) ],
        );

        _Send( $Client, 200, 'text/plain; version=0.0.4; charset=utf-8', $Body );
    }
    elsif ( $Path eq '/health' || $Path eq '/' ) {
        _Send( $Client, 200, 'text/plain', "OK\n" );
    }
    else {
        _Send( $Client, 404, 'text/plain', "404 Not Found\n" );
    }

    return;
}

sub _CollectMetrics {
    my ($Self) = @_;

    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
    my $QueueObject   = $Kernel::OM->Get('Kernel::System::Queue');
    my $StateObject   = $Kernel::OM->Get('Kernel::System::State');
    my $UserObject    = $Kernel::OM->Get('Kernel::System::User');
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

    my $Out = '';

    # -------------------------------------------------------------------
    # 1. Ticket totals by state type
    # -------------------------------------------------------------------
    {
        my @Lines;
        for my $StateType (qw(Open Pending Closed)) {
            my $Count = $TicketObject->TicketSearch(
                StateType => $StateType,
                UserID    => 1,
                Result    => 'COUNT',
            ) // 0;
            push @Lines,
                sprintf(
                'znuny_tickets_total{state_type="%s"} %d',
                lc($StateType), $Count
                );
        }
        $Out .= _GaugeBlock(
            Name  => 'znuny_tickets_total',
            Help  => 'Ticket count grouped by state type (open/pending/closed)',
            Lines => \@Lines,
        );
    }

    # -------------------------------------------------------------------
    # 2. Ticket count per individual state
    # -------------------------------------------------------------------
    {
        my %States = $StateObject->StateList( UserID => 1 );
        my @Lines;
        for my $StateID ( sort { $a <=> $b } keys %States ) {
            my $Count = $TicketObject->TicketSearch(
                StateIDs => [$StateID],
                UserID   => 1,
                Result   => 'COUNT',
            ) // 0;
            push @Lines,
                sprintf(
                'znuny_tickets_by_state{state="%s",state_id="%d"} %d',
                _Label( $States{$StateID} ), $StateID, $Count
                );
        }
        $Out .= _GaugeBlock(
            Name  => 'znuny_tickets_by_state',
            Help  => 'Ticket count per individual ticket state',
            Lines => \@Lines,
        );
    }

    # -------------------------------------------------------------------
    # 3. Open + total tickets per queue
    # -------------------------------------------------------------------
    {
        my %Queues = $QueueObject->GetAllQueues();
        my ( @OpenLines, @TotalLines );

        for my $QueueID ( sort { $a <=> $b } keys %Queues ) {
            my $QLabel = _Label( $Queues{$QueueID} );

            my $OpenCount = $TicketObject->TicketSearch(
                QueueIDs  => [$QueueID],
                StateType => 'Open',
                UserID    => 1,
                Result    => 'COUNT',
            ) // 0;
            push @OpenLines,
                sprintf(
                'znuny_queue_tickets_open{queue="%s",queue_id="%d"} %d',
                $QLabel, $QueueID, $OpenCount
                );

            my $TotalCount = $TicketObject->TicketSearch(
                QueueIDs => [$QueueID],
                UserID   => 1,
                Result   => 'COUNT',
            ) // 0;
            push @TotalLines,
                sprintf(
                'znuny_queue_tickets_total{queue="%s",queue_id="%d"} %d',
                $QLabel, $QueueID, $TotalCount
                );
        }

        $Out .= _GaugeBlock(
            Name  => 'znuny_queue_tickets_open',
            Help  => 'Number of open tickets per queue',
            Lines => \@OpenLines,
        );
        $Out .= _GaugeBlock(
            Name  => 'znuny_queue_tickets_total',
            Help  => 'Total number of tickets per queue (all states)',
            Lines => \@TotalLines,
        );
    }

    # -------------------------------------------------------------------
    # 4. Escalation / SLA metrics
    # -------------------------------------------------------------------
    {
        my $Escalated = $TicketObject->TicketSearch(
            TicketEscalationTimeOlderMinutes => -1,
            StateType                        => 'Open',
            UserID                           => 1,
            Result                           => 'COUNT',
        ) // 0;

        my $ResponseOverdue = $TicketObject->TicketSearch(
            TicketEscalationResponseTimeOlderMinutes => -1,
            StateType                                => 'Open',
            UserID                                   => 1,
            Result                                   => 'COUNT',
        ) // 0;

        my $UpdateOverdue = $TicketObject->TicketSearch(
            TicketEscalationUpdateTimeOlderMinutes => -1,
            StateType                              => 'Open',
            UserID                                 => 1,
            Result                                 => 'COUNT',
        ) // 0;

        my $SolutionOverdue = $TicketObject->TicketSearch(
            TicketEscalationSolutionTimeOlderMinutes => -1,
            StateType                                => 'Open',
            UserID                                   => 1,
            Result                                   => 'COUNT',
        ) // 0;

        my $EscalationWarn = $TicketObject->TicketSearch(
            TicketEscalationTimeNewerMinutes => -30,
            TicketEscalationTimeOlderMinutes =>  1,
            StateType                        => 'Open',
            UserID                           => 1,
            Result                           => 'COUNT',
        ) // 0;

        $Out .= _GaugeBlock(
            Name  => 'znuny_tickets_escalated',
            Help  => 'Open tickets that have breached the overall escalation deadline',
            Lines => ["znuny_tickets_escalated $Escalated"],
        );
        $Out .= _GaugeBlock(
            Name  => 'znuny_tickets_first_response_overdue',
            Help  => 'Open tickets overdue for first agent response (SLA breach)',
            Lines => ["znuny_tickets_first_response_overdue $ResponseOverdue"],
        );
        $Out .= _GaugeBlock(
            Name  => 'znuny_tickets_update_overdue',
            Help  => 'Open tickets overdue for follow-up update (SLA breach)',
            Lines => ["znuny_tickets_update_overdue $UpdateOverdue"],
        );
        $Out .= _GaugeBlock(
            Name  => 'znuny_tickets_solution_overdue',
            Help  => 'Open tickets overdue for resolution (SLA breach)',
            Lines => ["znuny_tickets_solution_overdue $SolutionOverdue"],
        );
        $Out .= _GaugeBlock(
            Name  => 'znuny_tickets_escalation_warning',
            Help  => 'Open tickets approaching escalation deadline (within 30 minutes)',
            Lines => ["znuny_tickets_escalation_warning $EscalationWarn"],
        );
    }

    # -------------------------------------------------------------------
    # 5. Agent counts
    # -------------------------------------------------------------------
    {
        my %ValidAgents = $UserObject->UserList(
            Type  => 'Short',
            Valid => 1
        );
        my %AllAgents = $UserObject->UserList(
            Type  => 'Short',
            Valid => 0
        );
        my $ValidCount   = scalar keys %ValidAgents;
        my $InvalidCount = ( scalar keys %AllAgents ) - $ValidCount;

        $Out .= _GaugeBlock(
            Name  => 'znuny_agents_total',
            Help  => 'Number of agent accounts by validity',
            Lines => [
                "znuny_agents_total{valid=\"true\"}  $ValidCount",
                "znuny_agents_total{valid=\"false\"} $InvalidCount",
            ],
        );
    }

    # -------------------------------------------------------------------
    # 6. Active sessions
    # -------------------------------------------------------------------
    {
        my @SessionIDs    = $SessionObject->GetAllSessionIDs();
        my %SessionCounts = (
            agent    => 0,
            customer => 0,
            unknown  => 0
        );

        for my $SessionID (@SessionIDs) {
            my %Data = $SessionObject->GetSessionIDData( SessionID => $SessionID );
            my $Type = $Data{UserType} // '';
            if    ( $Type eq 'User' )     { $SessionCounts{agent}++ }
            elsif ( $Type eq 'Customer' ) { $SessionCounts{customer}++ }
            else                          { $SessionCounts{unknown}++ }
        }

        $Out .= _GaugeBlock(
            Name  => 'znuny_sessions_active',
            Help  => 'Currently active Znuny sessions by user type',
            Lines => [
                "znuny_sessions_active{user_type=\"agent\"}    $SessionCounts{agent}",
                "znuny_sessions_active{user_type=\"customer\"} $SessionCounts{customer}",
                "znuny_sessions_active{user_type=\"unknown\"}  $SessionCounts{unknown}",
            ],
        );
    }

    # -------------------------------------------------------------------
    # 7. Tickets created today (local midnight boundary)
    # -------------------------------------------------------------------
    {
        my $DayStart = $Kernel::OM->Create('Kernel::System::DateTime')->Format( Format => '%Y-%m-%d 00:00:00' );

        my $CreatedToday = $TicketObject->TicketSearch(
            TicketCreateTimeNewerDate => $DayStart,
            UserID                    => 1,
            Result                    => 'COUNT',
        ) // 0;

        $Out .= _GaugeBlock(
            Name  => 'znuny_tickets_created_today',
            Help  => 'Number of tickets created since midnight (local server time)',
            Lines => ["znuny_tickets_created_today $CreatedToday"],
        );
    }

    # -------------------------------------------------------------------
    # 8. Ticket counts per type (only when Ticket::Type is active)
    # -------------------------------------------------------------------
    if ( $Self->{TypeEnabled} ) {
        my $TypeObject = $Kernel::OM->Get('Kernel::System::Type');
        my %Types      = $TypeObject->TypeList( Valid => 1 );
        my @Lines;

        for my $TypeID ( sort { $a <=> $b } keys %Types ) {
            my $Count = $TicketObject->TicketSearch(
                TypeIDs => [$TypeID],
                UserID  => 1,
                Result  => 'COUNT',
            ) // 0;
            push @Lines,
                sprintf(
                'znuny_tickets_by_type{type="%s",type_id="%d"} %d',
                _Label( $Types{$TypeID} ), $TypeID, $Count
                );
        }

        $Out .= _GaugeBlock(
            Name  => 'znuny_tickets_by_type',
            Help  => 'Ticket count per ticket type (only emitted when Ticket::Type is enabled)',
            Lines => \@Lines,
        );
    }

    # -------------------------------------------------------------------
    # 9. Ticket counts per service (only when Ticket::Service is active)
    #
    # Service is an optional attribute even when the feature is on, so
    # we emit a dedicated "no_service" bucket for tickets without one.
    # -------------------------------------------------------------------
    if ( $Self->{ServiceEnabled} ) {
        my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');
        my %Services      = $ServiceObject->ServiceList(
            Valid  => 1,
            UserID => 1,
        );
        my @Lines;
        my $AssignedTotal = 0;

        for my $ServiceID ( sort { $a <=> $b } keys %Services ) {
            my $Count = $TicketObject->TicketSearch(
                ServiceIDs => [$ServiceID],
                UserID     => 1,
                Result     => 'COUNT',
            ) // 0;
            $AssignedTotal += $Count;
            push @Lines,
                sprintf(
                'znuny_tickets_by_service{service="%s",service_id="%d"} %d',
                _Label( $Services{$ServiceID} ), $ServiceID, $Count
                );
        }

        # Tickets with no service assigned — total minus all service buckets.
        my $TotalAll = $TicketObject->TicketSearch(
            UserID => 1,
            Result => 'COUNT',
        ) // 0;
        my $NoService = $TotalAll - $AssignedTotal;

        push @Lines,
            sprintf( 'znuny_tickets_by_service{service="",service_id="0"} %d', $NoService );

        $Out .= _GaugeBlock(
            Name => 'znuny_tickets_by_service',
            Help =>
                'Ticket count per service; service="" means no service assigned (only emitted when Ticket::Service is enabled)',
            Lines => \@Lines,
        );
    }

    return ( $Out, 1 );
}

# ===========================================================================
# STATIC HELPERS
# ===========================================================================

sub _GaugeBlock {
    my (%Args) = @_;
    my $Name   = $Args{Name};
    my $Help   = $Args{Help};
    my @Lines  = ref $Args{Lines} ? @{ $Args{Lines} } : ( $Args{Lines} );

    return "# HELP $Name $Help\n"
        . "# TYPE $Name gauge\n"
        . join( "\n", @Lines ) . "\n"
        . "\n";
}

sub _Label {
    my ($Val) = @_;
    $Val =~ s/\\/\\\\/g;
    $Val =~ s/"/\\"/g;
    $Val =~ s/\n/\\n/g;
    return $Val;
}

sub _Send {
    my ( $Client, $Code, $ContentType, $Body ) = @_;
    my $Status = {
        200 => 'OK',
        404 => 'Not Found'
    }->{$Code} // 'OK';
    print $Client "HTTP/1.1 $Code $Status\r\n";
    print $Client "Content-Type: $ContentType\r\n";
    print $Client "Content-Length: " . length($Body) . "\r\n";
    print $Client "Connection: close\r\n";
    print $Client "\r\n";
    print $Client $Body;
    return;
}

1;
