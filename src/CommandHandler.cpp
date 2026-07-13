#include "CommandHandler.hpp"
#include "Response.hpp"

// Commands getCmd(const char buf[MAX_BUF]) {
//     if (!buf || std::strlen(buf) == 0) {
//         return INVALID;
//     }

//     std::string command(buf);

//     if (!command.empty() && command[0] == '/') {
//         command.erase(0, 1);
//     }

//     // Convert commands to uppercase CHANGE LATER
//     std::transform(command.begin(), command.end(), command.begin(), ::toupper);

//     // Extract the command keyword (up to first space or end of string)
//     size_t spacePos = command.find(' ');
//     std::string command_keyword = command.substr(0, spacePos);

//     static const std::unordered_map<std::string, Commands> command_map = {
//         {"PASS", PASS},
//         {"USER", USER},
//         {"NICK", NICK},
//         {"JOIN", JOIN},
//         {"PART", PART},
//         {"PRIVMSG", PRIVMSG}
//     };

//     auto it = command_map.find(command_keyword);
//     return (it != command_map.end()) ? it->second : INVALID;
// }

// std::vector<std::string> splitCmd(std::string& cmd)
std::vector<std::string> Server::splitCmd(std::string& cmd)
{
	std::vector<std::string> vec;
	std::istringstream stm(cmd);
	std::string token;
	while(stm >> token)
	{
		vec.push_back(token);
		token.clear();
	}
	return vec;
}

// Commands    getCmd(const char buf[Server::MAX_BUF]) {
//     std::string command(buf);
//     if (command[0] == '/')
//         command = command.substr(1);
//     std::string command_prefix = command.substr(0, 4);
//     std::transform(command_prefix.begin(), command_prefix.end(), command_prefix.begin(), ::toupper);

//     if (command_prefix == "PASS") {
//         return (PASS);
//     } else if (command_prefix == "USER") {
//         return (USER);
//     } else if (command_prefix == "NICK") {
//         return (NICK);
//     } else if (command_prefix == "JOIN") {
//         return (JOIN);
//     } else if (command_prefix == "PART") {
//         return (PART);
//     } else if (command_prefix == "PRIVMSG") {
//         return (PRIVMSG);
//     }
//     return (INVALID);
// }

// void    Client::handleBuffer(Client& client, const char buf[Server::MAX_BUF], const std::string& password, std::string& output) {
//     if (client.state == UNAUTHENTICATED) {
//         if (getCmd(buf) != PASS) {
//             output = "Please enter the password\r\n";
//             return ;
//         }
//         // Compare password with correct one here
//         std::string command(buf);
//         std::string providedPassword = command.substr(5);
//         if (providedPassword == password) {
//             client.state = AUTHENTICATED;
//             output = "User authenticated\r\n";
//         } else {
//             output = "Incorrect password\r\n";
//             return;
//         }
//     } else if (client.state == AUTHENTICATED) {
//         // Check if user enters USER and NICK here
//         if (getCmd(buf) == NICK) {
//             std::string command(buf);
//             client.nickname = command.substr(5);
//             output = client.nickname + "\r\n";
//         } else if (getCmd(buf) == USER) {
//             std::string command(buf);
//             client.username = command.substr(5);
//             output = client.username + "\r\n";
//         }
//         if (!client.nickname.empty() && !client.username.empty()) {
//             client.state = REGISTERED;
//             output = "User registered\r\n";
//         }
//     } else if (client.state == REGISTERED) {
//         // Handle normal commands here
//         if (getCmd(buf) == PRIVMSG) {
//             std::string command(buf);
//             size_t pos = command.find(":");
//             if (pos != std::string::npos) {
//                 std::string target = command.substr(8, pos - 8 - 1);
//                 std::string message = command.substr(pos + 1);
//                 // TODO: Send message to target
//                 output = "Sending message to " + target + ": " + message + "\r\n";
//             } else {
//                 output = "Invalid PRIVMSG format\r\n";
//             }
//         }
//     }
// }

void Server::client_authen(int fd, std::string cmd)
{
	Client *cli = GetClient(fd);
	cmd = cmd.substr(4);
	const size_t pos = cmd.find_first_not_of("\t\v ");
	if(pos < cmd.size())
	{
		cmd = cmd.substr(pos);
		if(cmd[0] == ':')
			cmd.erase(cmd.begin());
	}
	if (pos == std::string::npos || cmd.empty()) 
		_sendResponse(ERR_NOTENOUGHPARAM(std::string("*")), fd);
	else if (!cli->getRegistered())
	{
		const std::string& pass = cmd;
		if (pass == _password)
			cli->setRegistered(true);
		else
			_sendResponse(ERR_INCORPASS(std::string("*")), fd);
	}
	else
		_sendResponse(ERR_ALREADYREGISTERED(GetClient(fd)->GetNickName()), fd);
}

// bool Server::is_validNickname(std::string& nickname) {
static bool is_validNickname(std::string& nickname) {
		
	if (!nickname.empty() && (nickname[0] == '&' || nickname[0] == '#' || nickname[0] == ':'))
		return false;
	for(size_t i = 1; i < nickname.size(); i++) {
		if(!std::isalnum(nickname[i]) && nickname[i] != '_')
			return false;
	}
	return true;
}

bool Server::nickNameInUse(std::string& nickname) {
	for (size_t i = 0; i < this->clients.size(); i++)
	{
		if (this->clients[i].GetNickName() == nickname)
			return true;
	}
	return false;
}

void Server::set_nickname(std::string cmd, int fd) {
	std::string inuse;
	cmd = cmd.substr(4);
	const size_t pos = cmd.find_first_not_of("\t\v ");
	if (pos < cmd.size()) {
		cmd = cmd.substr(pos);
		if (cmd[0] == ':') {
			cmd.erase(cmd.begin());
		}
	}
	Client *cli = GetClient(fd);
	if(pos == std::string::npos || cmd.empty()) {
		_sendResponse(ERR_NOTENOUGHPARAM(std::string("*")), fd);
		return;
	}
	if (nickNameInUse(cmd) && cli->GetNickName() != cmd) {
		inuse = "*";
		if (cli->GetNickName().empty()) {
			cli->SetNickname(inuse);
		}
	    _sendResponse(ERR_NICKINUSE(std::string(cmd)), fd); 
		return ;
	}
	if(!is_validNickname(cmd)) {
		_sendResponse(ERR_ERRONEUSNICK(std::string(cmd)), fd);
		return ;
	}
	else {
		if (cli && cli->getRegistered()) {
			const std::string oldnick = cli->GetNickName();
			cli->SetNickname(cmd);
			for(size_t i = 0; i < channels.size(); i++) {
				Client *cl = channels[i].GetClientInChannel(oldnick);
				if (cl) {
					cl->SetNickname(cmd);
				}
			}
			if(!oldnick.empty() && oldnick != cmd) {
				if (oldnick == "*" && !cli->GetUserName().empty()) {
					cli->setLogedin(true);
					_sendResponse(RPL_CONNECTED(cli->GetNickName()), fd);
					_sendResponse(RPL_NICKCHANGE(cli->GetNickName(),cmd), fd);
				}
				else {
					_sendResponse(RPL_NICKCHANGE(oldnick,cmd), fd);
				}
				return ;
			}
			
		}
		else if (cli && !cli->getRegistered()) {
			_sendResponse(ERR_NOTREGISTERED(cmd), fd);
		}
	}
	if(cli && cli->getRegistered() && !cli->GetUserName().empty() && !cli->GetNickName().empty() && cli->GetNickName() != "*" && !cli->GetLogedIn()) {
		cli->setLogedin(true);
		_sendResponse(RPL_CONNECTED(cli->GetNickName()), fd);
	}
}

void	Server::set_username(std::string& cmd, int fd)
{
	std::vector<std::string> splited_cmd = splitCmd(cmd);

	Client *cli = GetClient(fd); 
	if((cli && splited_cmd.size() < 5)) {
		_sendResponse(ERR_NOTENOUGHPARAM(cli->GetNickName()), fd);
		return;
	}
	if(!cli  || !cli->getRegistered()) {
		_sendResponse(ERR_NOTREGISTERED(std::string("*")), fd);
	}
	else if (cli && !cli->GetUserName().empty()) {
		_sendResponse(ERR_ALREADYREGISTERED(cli->GetNickName()), fd);
		return;
	}
	else {
		cli->SetUsername(splited_cmd[1]);
	}
	if((cli != 0) && cli->getRegistered() && !cli->GetUserName().empty() && !cli->GetNickName().empty() && cli->GetNickName() != "*"  && !cli->GetLogedIn())
	{
		cli->setLogedin(true);
		_sendResponse(RPL_CONNECTED(cli->GetNickName()), fd);
	}
}
