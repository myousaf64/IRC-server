#include "../inc/Client.hpp"

Client::Client(int fd): fd(fd) {
    isOperator = false;
    state = UNAUTHENTICATED;
    registered = false;
    logedin = false;
}

Client::Client() {
	this->nickname = "";
	this->username = "";
	this->fd = -1;
	this->isOperator= false;
	this->registered = false;
	this->buffer = "";
	this->ipadd = "";
	this->logedin = false;
	this->state = UNAUTHENTICATED;
}

Client::Client(const std::string &nickname, const std::string &username, int fd)
	:fd(fd), nickname(nickname), username(username), state(UNAUTHENTICATED),
	isOperator(false), registered(false), logedin(false) { }
Client::~Client( ) { }
Client::Client( Client const &src ) { *this = src; }

Client &Client::operator=(Client const &src){
	if (this != &src){
		this->nickname = src.nickname;
		this->username = src.username;
		this->fd = src.fd;
		this->ChannelsInvite = src.ChannelsInvite;
		this->buffer = src.buffer;
		this->registered = src.registered;
		this->ipadd = src.ipadd;
		this->logedin = src.logedin;
		this->state = src.state;
	}
	return *this;
}

int Client::GetFd( ) { return this->fd; }
bool Client::getRegistered( ) { return registered; }
bool Client::GetInviteChannel( std::string &ChName ) {
	for (size_t i = 0; i < this->ChannelsInvite.size(); i++) {
		if (this->ChannelsInvite[i] == ChName)
			return true;
	}
	return false;
}
std::string Client::GetNickName( ){ return this->nickname; }
bool Client::GetLogedIn( ) { return this->logedin; }
std::string Client::GetUserName( ) { return this->username; }
std::string Client::getBuffer( ) { return buffer; }
std::string Client::getIpAdd( ) { return ipadd; }
std::string Client::getHostname( ) {
	std::string hostname = this->GetNickName() + "!" + this->GetUserName();
	return hostname;
}

void Client::SetFd( int fd ) { this->fd = fd; }
void Client::SetNickname( std::string& nickName ) { this->nickname = nickName; }
void Client::setLogedin(bool value){this->logedin = value; }
void Client::SetUsername(std::string& username){this->username = username; }
void Client::setBuffer(const std::string &recived){buffer += recived; }
void Client::setRegistered(bool value){registered = value; }
void Client::setIpAdd(const std::string &ipadd){this->ipadd = ipadd; }

void Client::clearBuffer() { buffer.clear(); }
void Client::AddChannelInvite( std::string &chname ) {
	ChannelsInvite.push_back( chname );
}
void Client::RmChannelInvite( std::string &chname ) {
	for (size_t i = 0; i < this->ChannelsInvite.size(); i++) {
		if (this->ChannelsInvite[i] == chname)
			{this->ChannelsInvite.erase(this->ChannelsInvite.begin() + i); return;}
	}
}
