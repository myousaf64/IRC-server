#include "../../inc/Server.hpp"

void FindK(const std::string &cmd, const std::string &tofind, std::string &str)
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
            } else {
                tmp.clear();
            }
        }
    }
    if (i < cmd.size()) {
        str = cmd.substr(i);
    }
    for (i = 0; i < str.size() && str[i] == ' '; i++) { /** skips spaces */ }
    str = str.substr(i);
}

std::string SplitCmdK(std::string &cmd, std::vector<std::string> &tmp)
{
    std::stringstream ss(cmd);
    std::string str;
    int count = 3;
    while (ss >> str && count > 0) {
        tmp.push_back(str);
        count--;
    }
    if (tmp.size() != 3) {
        return std::string("");
    }
    std::string reason;
    FindK(cmd, tmp[2], reason);
    return reason;
}

std::string Server::SplitCmdKick(const std::string &cmd, std::vector<std::string> &tmp, std::string &user, int fd)
{
    std::string cmdCopy = cmd;
    std::string reason = SplitCmdK(cmdCopy, tmp);
    if (tmp.size() < 3) {
        return std::string("");
    }
    tmp.erase(tmp.begin());
    std::string str = tmp[0];
    std::string str1;
    user = tmp[1];
    tmp.clear();
    for (size_t i = 0; i < str.size(); i++) {
        if (str[i] == ',') {
            tmp.push_back(str1);
            str1.clear();
        } else {
            str1 += str[i];
        }
    }
    tmp.push_back(str1);
    for (size_t i = 0; i < tmp.size(); i++) {
        if (tmp[i].empty()) {
            tmp.erase(tmp.begin() + static_cast<std::vector<std::string>::difference_type>(i));
            i--;
        }
    }
    if (!reason.empty() && reason[0] == ':') {
        reason.erase(reason.begin());
    } else {
        for (size_t i = 0; i < reason.size(); i++) {
            if (reason[i] == ' ') {
                reason.resize(i);
                break;
            }
        }
    }
    for (size_t i = 0; i < tmp.size(); i++) {
        if (!tmp[i].empty() && tmp[i][0] == '#') {
            tmp[i].erase(tmp[i].begin());
        } else {
            senderror(403, GetClient(fd)->GetNickName(), tmp[i], GetClient(fd)->GetFd(), " :No such channel\r\n");
            tmp.erase(tmp.begin() + static_cast<std::vector<std::string>::difference_type>(i));
            i--;
        }
    }
    return reason;
}

void Server::KICK(const std::string &cmd, int fd) {
    std::vector<std::string> tmp;
    std::string reason;
    std::string user;
    reason = SplitCmdKick(cmd, tmp, user, fd);
    if (user.empty()) {
        senderror(461, GetClient(fd)->GetNickName(), GetClient(fd)->GetFd(), " :Not enough parameters\r\n");
        return;
    }
    for (size_t i = 0; i < tmp.size(); i++) {
        Channel *ch = GetChannel(tmp[i]);
        if (ch != NULL) {
            if (ch->get_client(fd) == NULL && ch->get_admin(fd) == NULL) {
                senderror(442, GetClient(fd)->GetNickName(), "#" + tmp[i], GetClient(fd)->GetFd(), " :You're not on that channel\r\n");
                continue;
            }
            if (ch->get_admin(fd) != NULL) {
                Client *targetClient = ch->GetClientInChannel(user);
                if (targetClient != NULL) {
                    std::stringstream ss;
                    ss << ":" << GetClient(fd)->GetNickName() << "!~" << GetClient(fd)->GetUserName()
                       << "@" << "localhost"
                       << " KICK #" << tmp[i] << " " << user;
                    if (!reason.empty()) {
                        ss << " :" << reason << "\r\n";
                    } else {
                        ss << "\r\n";
                    }
                    ch->sendTo_all(ss.str());
                    if (ch->get_admin(targetClient->GetFd()) != NULL) {
                        ch->remove_admin(targetClient->GetFd());
                    } else {
                        ch->remove_client(targetClient->GetFd());
                    }
                    if (ch->GetClientsNumber() == 0) {
                        channels.erase(channels.begin() + static_cast<std::vector<Channel>::difference_type>(i));
                    }
                } else {
                    senderror(441, GetClient(fd)->GetNickName(), "#" + tmp[i], GetClient(fd)->GetFd(), " :They aren't on that channel\r\n");
                    continue ;
                }
            } else {
                senderror(482, GetClient(fd)->GetNickName(), "#" + tmp[i], GetClient(fd)->GetFd(), " :You're not channel operator\r\n");
                continue ;
            }
        } else {
            senderror(403, GetClient(fd)->GetNickName(), "#" + tmp[i], GetClient(fd)->GetFd(), " :No such channel\r\n");
        }
    }
}
