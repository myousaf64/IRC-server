// CommandHandler.hpp
#pragma once

#include "Client.hpp"
#include "Utils.hpp"
#include "Server.hpp"
#include <string>

enum Commands {
    PASS,
    NICK,
    USER,
    JOIN,
    PART,
    PRIVMSG,
    INVALID,
};

void    handlePass();
void    handleNick();
void    handleUser();
void    handleJoin();
void    handlePart();

class Client;

std::vector<std::string> splitCmd(std::string& cmd);

/** 
 * General buffer handler which calls the appropriate
 * functions based on the buffer (user input)
 */
void    handleBuffer( Client& client, const char buf[512], const std::string& password, std::string& output );
