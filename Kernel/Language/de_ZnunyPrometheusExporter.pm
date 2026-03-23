# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_ZnunyPrometheusExporter;

use strict;
use warnings;

use utf8;

sub Data {
    my $Self = shift;

    $Self->{Translation}->{'Prometheus metrics exporter daemon module. Exposes a /metrics HTTP endpoint on the configured port.'}
        = 'Daemon-Modul für den Prometheus-Metrik-Exporter. Stellt den HTTP-Endpunkt /metrics auf dem konfigurierten Port bereit.';

    $Self->{Translation}->{'TCP port for the Prometheus metrics exporter (default: 10111).'}
        = 'TCP-Port für den Prometheus-Metrik-Exporter (Standard: 10111).';

    $Self->{Translation}->{'IP address the Prometheus metrics exporter binds to (default: 127.0.0.1). Use 0.0.0.0 to listen on all interfaces.'}
        = 'IP-Adresse, an die der Prometheus-Metrik-Exporter bindet (Standard: 127.0.0.1). 0.0.0.0 verwenden, um auf allen Schnittstellen zu lauschen.';

    return 1;
}

1;
