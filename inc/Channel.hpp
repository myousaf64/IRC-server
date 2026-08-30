// Channel.hpp
#pragma once

#include <string>
#include <vector>
#include "Client.hpp"

static const int MAX_CLIENT_LIMIT = 5;

class Client;
class Channel {
private:
	int		inviteOnly;
	int		topic;
	int		keyEnabled;
	int		limit;
	bool	topicRestricted;
	// int 	clientLimit;
	// bool 	clientLimitEnabled;
	std::string	name;
	std::string	time_creation;
	std::string	password;
	std::string	created_at;
	std::string	topic_name;
	std::vector<Client>	clients;
	std::vector<Client>	admins;
	std::vector<std::pair<char, bool> >	modes;

public:
	// Constructor to initialize members
	// Channel(  )
	// 	: inviteOnly( false ),
	// 		topicRestricted( false ),
	// 		keyEnabled( false ),
	// 		clientLimitEnabled( false ),
	// 		clientLimit( MAX_CLIENT_LIMIT ) 
	// {}
	Channel( );
	~Channel( );
	Channel( Channel const &src );
	Channel &operator=( Channel const &src );

	/** Setters */
	void SetInvitOnly( int inviteOnly );
	void SetTopic( int topic );
	void SetKey( int keyEnabled );
	void SetLimit( int limit );
	void SetTopicName( const std::string &topic_name );
	void SetPassword( const std::string &password );
	void SetName( const std::string &name );
	void SetTime( const std::string &time );
	void set_topicRestriction( bool value );
	void setModeAtindex( size_t index, bool mode );
	void set_createiontime(  );
	/** Getters */
	int GetInvitOnly(  );
	int GetTopic(  );
	int GetKey(  );
	int GetLimit(  );
	int GetClientsNumber(  );
	bool Gettopic_restriction( ) const;
	bool getModeAtindex( size_t index );
	bool clientInChannel( std::string &nick );
	std::string GetTopicName(  );
	std::string GetPassword(  );
	std::string GetName(  );
	std::string GetTime(  );
	std::string get_creationtime(  );
	std::string getModes(  );
	std::string clientChannel_list(  );
	Client *get_client( int fd );
	Client *get_admin( int fd );
	Client *GetClientInChannel( const std::string &name );
	/** Methods */
	void add_client( Client newClient );
	void add_admin( Client newClient );
	void remove_client( int fd );
	void remove_admin( int fd );
	bool change_clientToAdmin( std::string& nick );
	bool change_adminToClient( std::string& nick );
	/** SendToAll */
	void sendTo_all( const std::string &rpl1 );
	void sendTo_all( const std::string &rpl1, int fd );

};

// struct ChannelMode {
//     bool        inviteOnly = false;
//     bool        topicRestricted = false;
//     bool        keyEnabled = false;
//     std::string key;
//     bool        clientLimitEnabled = false;
//     int         clientLimit = 0;
// };

// class Channel {
//     public:
//         std::string     name;
//         std::set<int>   members;
//         std::set<int>   operators;
//         ChannelMode     mode;
//         std::string     topic;

//         Channel(  const std::string& name, int creatorFd  );
// };
