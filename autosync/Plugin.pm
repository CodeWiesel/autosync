# AutoSync copyright (c) 2017 Mark Hässig
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2, which should be included with this software.
# 
# Portions of this code might be derived from code with the 
# following copyright message and released under the same license terms:
#
# SliMP3 Server Copyright (C) 2001 Sean Adams, Slim Devices Inc.
# SlimServer Copyright (c) 2001-2006 Sean Adams, Slim Devices Inc.
# 

package Plugins::AutoSync::Plugin;

use strict;

use Slim::Utils::Log;
use Slim::Control::Request;
use Slim::Control::Jive;
use Slim::Player::Sync;

# create a logging object
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.AutoSync',
	'defaultLevel' => 'ERROR',
	'description'  => getMyDisplayName(),
});

my $syncMaster = undef;

sub initPlugin {
	# Subscribe to power events
	Slim::Control::Request::subscribe(\&powerCallback,[['power']]);
	Slim::Control::Request::subscribe(\&playCallback,[['play']]);
}

sub getMyDisplayName() {
	return 'PLUGIN_AUTOSYNC';
}

sub shutdownPlugin {
	Slim::Control::Request::unsubscribe( \&powerCallback );
	Slim::Control::Request::unsubscribe( \&playCallback );
}

sub playCallback {
	my $request = shift;
	my $client = $request->client() || return;
	$log->debug("playCallback entered $client");
	if(!defined $syncMaster){
		setNewMaster($client);
	}
	$log->debug("playCallback left");
}
sub setNewMaster {
	my ( $client ) = @_;
	$log->debug("setNewMaster entered $client");
	disconnectPlayerIfConnected($client);
	$syncMaster = $client;
	$log->debug("setNewMaster left");
	return $syncMaster;
}

sub syncPlayer {
	my ( $client ) = @_;
	$log->debug("syncPlayer entered $client");
	disconnectPlayerIfConnected($client);
	$syncMaster->controller()->sync($client, '1');
	$log->debug("syncPlayer left");
	return;
}


sub disconnectPlayerIfConnected {
	my ( $client ) = @_;
	$log->debug("disconnectPlayerIfConnected entered $client");
	if(Slim::Player::Sync::isMaster($client) || Slim::Player::Sync::isSlave($client)){
		$client->controller()->unsync($client);
	}
	$log->debug("disconnectPlayerIfConnected left");
	return;
}

sub powerCallback {
	my $request = shift;
	my $client = $request->client() || return;
	$log->debug("powerCallback entered $client");
	my $clientPower =  $client->power;
	$log->debug("Client Power State: $clientPower");
	# check if client is running
	if (! $clientPower ) {
		if($client == $syncMaster) {
			my @slaves = Slim::Player::Sync::slaves($client);
			disconnectPlayerIfConnected($client);
			# pass master on to next slave or power off all?
			for my $slave (@slaves) {
				Slim::Control::Jive::playerPower($slave);
			}
		}
		else{
			disconnectPlayerIfConnected($client);
		}
		
		return;
	}
	if(defined $syncMaster){
		syncPlayer($client);
	}
	$log->debug("powerCallback left");
	return;
}

1;