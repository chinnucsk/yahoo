%%%-------------------------------------------------------------------
%%% @author Anton I Alferov <casper@ubca-dp>
%%% @copyright (C) 2013, Anton I Alferov
%%%
%%% Created: 01 Mar 2013 by Anton I Alferov <casper@ubca-dp>
%%%-------------------------------------------------------------------

-module(yahoo_messenger_notification).
-export([read/1]).

-include("yahoo_messenger_notification.hrl").

-define(DisconnectReason(Code), case Code of
	1 -> regen;
	2 -> idle;
	3 -> queue_full;
	4 -> self_logoff
end).

read([]) -> idle;
read(Notification) ->
	lists:foldl(fun([{Type, Details}], Acc) -> update(Acc, read(Type, Details))
	end, #yahoo_notification{}, utils_lists:keyfind2(responses, Notification)).

read(buddyInfo, BuddyInfo) ->
	{utils_lists:keyfind2(sequence, BuddyInfo), #yahoo_buddy_info{
		buddies = case utils_lists:keyfind(contact, BuddyInfo) of
			{ok, Contacts} -> [#yahoo_buddy{
				sender = field(sender, Contact),
				presence_message = field(presenceMessage, Contact)
			} || Contact <- Contacts];
			{error, not_found} -> []
		end
	}};

read(buddyStatus, BuddyStatus) ->
	{utils_lists:keyfind2(sequence, BuddyStatus), #yahoo_buddy_status{}};

read(logOff, LogOff) -> {utils_lists:keyfind2(sequence, LogOff),
	#yahoo_log_off{buddy = field(buddy, LogOff)}};

read(message, Message) ->
	{utils_lists:keyfind2(sequence, Message), read_message(Message)};

read(offlineMessage, OfflineMessage) ->
	ReadMessage = fun(Message) -> read_message(
		utils_lists:keyfind2(message, Message)) end,
	{utils_lists:keyfind2(sequence, OfflineMessage),
		#yahoo_offline_message{messages = lists:map(ReadMessage,
			utils_lists:keyfind2(messages, OfflineMessage))}
	};

read(disconnect, Disconnect) ->
	{utils_lists:keyfind2(sequence, Disconnect), #yahoo_disconnect{
		reason = ?DisconnectReason(utils_lists:keyfind2(reason, Disconnect))}};

read(_, Notification) -> {utils_lists:keyfind2(sequence, Notification), []}.

read_message(Message) -> #yahoo_message{
	sender = field(sender, Message),
	msg = field(msg, Message),
	time_stamp = utils_lists:keyfind2(timeStamp, Message)
}.

update(N = _Notification, {Sequence, Response}) -> N#yahoo_notification{
	sequence = if Sequence > N#yahoo_notification.sequence -> Sequence;
		true -> N#yahoo_notification.sequence end,
	responses = [Response|N#yahoo_notification.responses]
}.

field(Name, List) -> case utils_lists:keyfind(Name, List) of
	{ok, Field} -> binary_to_list(Field); {error, not_found} -> [] end.
