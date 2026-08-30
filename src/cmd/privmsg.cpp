#include "../../inc/Server.hpp"

void FindPM(const std::string& cmd, const std::string& tofind, std::string& str)
{
    size_t i = 0;
    for (; i < cmd.size(); i++) {
        if (cmd[i] != ' ') {
            std::string tmp;
            for (; i < cmd.size() && cmd[i] != ' '; i++) {
                tmp += cmd[i];
            }
            if (tmp == tofind) {
                break;
            }
            else {
                tmp.clear();
            }
        }
    }
    if (i < cmd.size()) {
        str = cmd.substr(i);
    }
    i = 0;
    for (; i < str.size() && str[i] == ' '; i++) { /** skip spaces */ }
    str = str.substr(i);
}

std::string SplitCmdPM(std::string& cmd, std::vector<std::string>& tmp)
{
    std::stringstream ss(cmd);
    std::string str;
    std::string msg;
    int count = 2;
    while ((ss >> str) && (count > 0)) {
        tmp.push_back(str);
        count--;
    }
    if (tmp.size() != 2) {
        return std::string("");
    }
    FindPM(cmd, tmp[1], msg);
    return msg;
}

std::string SplitCmdPrivmsg(const std::string& cmd, std::vector<std::string>& tmp)
{
    std::string str = SplitCmdPM(const_cast<std::string&>(cmd), tmp);
    if (tmp.size() != 2) {
        tmp.clear();
        return std::string("");
    }
    tmp.erase(tmp.begin());
    std::string str1 = tmp[0];
    std::string str2;
    tmp.clear();
    for (size_t i = 0; i < str1.size(); i++) {
        if (str1[i] == ',') {
            tmp.push_back(str2);
            str2.clear();
        }
        else {
            str2 += str1[i];
        }
    }
    tmp.push_back(str2);
    for (size_t i = 0; i < tmp.size(); i++) {
        if (tmp[i].empty()) {
            tmp.erase(tmp.begin() + static_cast<std::vector<std::string>::difference_type>(i));
            i--;
        }
    }
    if (!str.empty() && str[0] == ':') {
        str.erase(str.begin());
    }
    else {
        for (size_t i = 0; i < str.size(); i++) {
            if (str[i] == ' ') {
                str.resize(i);
                break;
            }
        }
    }
    return str;
}

void Server::CheckForChannels_Clients(std::vector<std::string>& tmp, int fd)
{
    for (size_t i = 0; i < tmp.size(); i++) {
        if (!tmp[i].empty() && tmp[i][0] == '#') {
            tmp[i].erase(tmp[i].begin());
            if (!GetChannel(tmp[i])) {
                senderror(401, "#" + tmp[i], GetClient(fd)->GetFd(), " :No such nick/channel\r\n");
                tmp.erase(tmp.begin() + static_cast<std::vector<std::string>::difference_type>(i));
                i--;
            }
            else if (!GetChannel(tmp[i])->GetClientInChannel(GetClient(fd)->GetNickName())) {
                senderror(404, GetClient(fd)->GetNickName(), "#" + tmp[i], GetClient(fd)->GetFd(), " :Cannot send to channel\r\n");
                tmp.erase(tmp.begin() + static_cast<std::vector<std::string>::difference_type>(i));
                i--;
            }
            else {
                tmp[i] = "#" + tmp[i];
            }
        }
        else {
            if (!GetClientNick(tmp[i])) {
                senderror(401, tmp[i], GetClient(fd)->GetFd(), " :No such nick/channel\r\n");
                tmp.erase(tmp.begin() + static_cast<std::vector<std::string>::difference_type>(i));
                i--;
            }
        }
    }
}

void Server::PRIVMSG(const std::string& cmd, int fd)
{
    std::vector<std::string> tmp;
    const std::string message = SplitCmdPrivmsg(cmd, tmp);
    if (tmp.empty()) {
        senderror(411, GetClient(fd)->GetNickName(), GetClient(fd)->GetFd(), " :No recipient given (PRIVMSG)\r\n");
        return;
    }
    if (message.empty()) {
        senderror(412, GetClient(fd)->GetNickName(), GetClient(fd)->GetFd(), " :No text to send\r\n");
        return;
    }
    if (tmp.size() > 10) {
        senderror(407, GetClient(fd)->GetNickName(), GetClient(fd)->GetFd(), " :Too many recipients\r\n");
        return;
    }
    CheckForChannels_Clients(tmp, fd);
    for (size_t i = 0; i < tmp.size(); i++) {
        if (!tmp[i].empty() && tmp[i][0] == '#') {
            tmp[i].erase(tmp[i].begin());
            const std::string resp = ":" + GetClient(fd)->GetNickName() + "!~" + GetClient(fd)->GetUserName() + "@localhost PRIVMSG #" + tmp[i] + " :" + message + "\r\n";
            GetChannel(tmp[i])->sendTo_all(resp, fd);
        }
        else {
            const std::string resp = ":" + GetClient(fd)->GetNickName() + "!~" + GetClient(fd)->GetUserName() + "@localhost PRIVMSG " + tmp[i] + " :" + message + "\r\n";
            _sendResponse(resp, GetClientNick(tmp[i])->GetFd());
        }
    }
}
