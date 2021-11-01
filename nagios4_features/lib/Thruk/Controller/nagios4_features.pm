package Thruk::Controller::nagios4_features;

use strict;

sub map {
  my ( $c ) = @_;

  return unless Thruk::Action::AddDefaults::add_defaults(
    $c, Thruk::Constants::ADD_CACHED_DEFAULTS
  );

  $c->stash->{title} = 'Map ( Nagios4 feature )';
  $c->stash->{template} = 'map.tt';
  $c->stash->{thruk_logos} = $c->config->{'logo_path_prefix'};

  my $layout = $c->config->{'Thruk::Plugin::Nagios4_Features'}
    ->{'default_statusmap_layout'} || 6;
  $c->stash->{map_layout} = $layout;
}

sub statusjson {
  my ( $c ) = @_;

  return unless Thruk::Action::AddDefaults::add_defaults(
    $c, Thruk::Constants::ADD_CACHED_DEFAULTS
  );

  my $query = $c->req->parameters->{'query'} || 'hostlist';

  my $json = {
    format_version => 0,
    result => {
      cgi => 'statusjson.cgi',
      user => $c->stash->{'remote_user'},
      query => $query,
      'query_status' => 'released',
      'type_code' => 0,
      'type_text' => 'Success',
      message => '',
    },
    data => {
      programstatus => {
        version => '4.4.6',
        nagios_pid => '?',
        enable_notifications => 'true',
        execute_service_checks => 'true'
      },
      selectors => {}
    }
  };

  my ( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c);
  return if $c->stash->{'has_error'};

  # hostlist
  if ($query eq 'hostlist')
  {
    my $hosts = $c->db->get_hosts(
      filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ],
      columns => [ qw/
        name address state plugin_output long_plugin_output last_check last_state_change
        /]
    );
    # $json->{data}{hosts_from_thrukdb} = $hosts; # for development

    for my $host (@{ $hosts })
    {
      my $status = 'unknown';
      $status = 'up' if $host->{state} eq 0;
      $status = 'down' if $host->{state} eq 1;
      $status = 'unreachable' if $host->{state} eq 2;

      my $plugin_output = $host->{plugin_output}."\n".$host->{long_plugin_output};
      $plugin_output =~ s/\\n/\n/g;

      $json->{data}{hostlist}{$host->{name}} = {
        name => $host->{name},
        address => $host->{address},
        status => $status,
        plugin_output => $plugin_output,
        last_check => $host->{last_check} * 1000,
        last_state_change => $host->{last_state_change} * 1000
      };
    }
  }
  elsif ($query eq 'servicelist')
  {
    my $services = $c->db->get_services( filter =>
      [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter, description => { '~~' => "" } ],
      columns => [ qw/
        description host_name state
        /]
    );
    # $json->{data}{services_from_thrukdb} = $services; # for development

    for my $service (@{ $services })
    {
      my $status = $service->{state};
      $status = 'ok' if $status eq 0;
      $status = 'warning' if $status eq 1;
      $status = 'critical' if $status eq 2;
      $status = 'unknown' if $status eq 3;

      $json->{data}{servicelist}{$service->{host_name}}
        {$service->{description}} = $status;
    }
  }

  $c->render(json => $json);
}

sub objectjson {
  my ( $c ) = @_;

  return unless Thruk::Action::AddDefaults::add_defaults(
    $c, Thruk::Constants::ADD_CACHED_DEFAULTS
  );

  my $query = $c->req->parameters->{'query'} || 'hostlist';
  my $details = $c->req->parameters->{'details'} || 'false';

  my $json = {
    format_version => 0,
    result => {
      cgi => 'objectjson.cgi',
      user => $c->stash->{'remote_user'},
      query => $query,
      'query_status' => 'released',
      'type_code' => 0,
      'type_text' => 'Success',
      message => '',
    },
    data => {
      selectors => {}
    }
  };

  my ( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c);
  return if $c->stash->{'has_error'};

  # hostlist
  if ($query eq 'hostlist')
  {
    my $hosts = $c->db->get_hosts(filter =>
      [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ],
      columns => [ qw/
        name address display_name alias parents childs icon_image
        /]
    );
    # $json->{data}{hosts_from_thrukdb} = $hosts; # for development

    if ($details eq 'true')
    {
      for my $host (@{ $hosts })
      {
        $json->{data}{hostlist}{$host->{name}} = {
          name => $host->{name},
          display_name => $host->{display_name},
          address => $host->{address},
          alias => $host->{alias},
          parent_hosts => $host->{parents},
          child_hosts => $host->{childs},
          icon_image => $host->{'icon_image'},
        };
      }
    }
    else
    {
      for my $host (@{ $hosts })
      {
        push @{ $json->{data}{hostlist} }, $host->{name};
      }
    }
  }

  # servicelist
  elsif ($query eq 'servicelist')
  {
    my $services = $c->db->get_services( filter =>
      [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter, description => { '~~' => "" } ],
      columns => [ qw/
        description host_name
        /]
    );
    # $json->{data}{services_from_thrukdb} = $services; # for development

    for my $service (@{ $services })
    {
      push @{ $json->{data}{servicelist}{$service->{host_name}} },
        $service->{description};
    }
  }

  $c->render(json => $json);
}

1;
