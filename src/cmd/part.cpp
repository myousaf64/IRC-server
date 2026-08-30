#include "../../inc/Server.hpp"

void FindPR(const std::string& tofind, const std::string& cmd, std::string &str)
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
    i = 0;
    for (; i < str.size() && str[i] == ' '; i++) { /** skip spaces */ }
    str = str.substr(i);
}

std::string SplitCmdPR(std::string &cmd, std::vector<std::string> &tmp)
{
    std::stringstream ss(cmd);
    std::string str;
    std::string reason;
    int count = 2;
    while ((ss >> str) && (count > 0)) {
        tmp.push_back(str);
        --count;
    }
    if (tmp.size() != 2) {
        return std::string("");
    }
    FindPR(tmp[1], cmd, reason);
    return reason;
}

int Server::SplitCmdPart(const std::string& cmd, std::vector<std::string> &tmp, std::string &reason, int fd) {
    reason = SplitCmdPR(const_cast<std::string&>(cmd), tmp);
    if (tmp.size() < 2) {
        tmp.clear();
        return 0;
    }
    tmp.erase(tmp.begin());
    std::string str = tmp[0];
    std::string str1;
    tmp.clear();
    for (size_t i = 0; i < str.size(); i++) { // split by ','
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
        if (!tmp[i].empty() && *(tmp[i].begin()) == '#') {
            tmp[i].erase(tmp[i].begin());
        } else {
            senderror(403, GetClient(fd)->GetNickName(), tmp[i], GetClient(fd)->GetFd(), " :No such channel\r\n");
            tmp.erase(tmp.begin() + static_cast<std::vector<std::string>::difference_type>(i));
            i--;
        }
    }
    return 1;
}

void Server::PART(const std::string& cmd, int fd) {
    std::vector<std::string> tmp;
    std::string reason;
    if (SplitCmdPart(cmd, tmp, reason, fd) == 0) {
        senderror(461, GetClient(fd)->GetNickName(), GetClient(fd)->GetFd(), " :Not enough parameters\r\n");
        return;
    }
    for (size_t i = 0; i < tmp.size(); i++) {
        bool flag = false;
        for (size_t j = 0; j < this->channels.size(); j++) {
            if (this->channels[j].GetName() == tmp[i]) {
                flag = true;
                if (channels[j].get_client(fd) == NULL && channels[j].get_admin(fd) == NULL) { // not on channel
                    senderror(442, GetClient(fd)->GetNickName(), "#" + tmp[i], GetClient(fd)->GetFd(), " :You're not on that channel\r\n");
                    continue ;
                }
                std::stringstream ss;
                ss << ":" << GetClient(fd)->GetNickName() << "!~" << GetClient(fd)->GetUserName() << "@" << "localhost" << " PART #" << tmp[i];
                if (!reason.empty()) {
                    ss << " :" << reason << "\r\n";
                } else {
                    ss << "\r\n";
                }
                channels[j].sendTo_all(ss.str());
                Client* clientPtr = channels[j].GetClientInChannel(GetClient(fd)->GetNickName());
                if (clientPtr != NULL && channels[j].get_admin(clientPtr->GetFd()) != NULL) {
                    channels[j].remove_admin(clientPtr->GetFd());
                } else if (clientPtr != NULL) {
                    channels[j].remove_client(clientPtr->GetFd());
                }
                if (channels[j].GetClientsNumber() == 0) {
                    channels.erase(channels.begin() + static_cast<std::vector<Channel>::difference_type>(j));
                }
            }
        }
        if (!flag) {
            senderror(403, GetClient(fd)->GetNickName(), "#" + tmp[i], GetClient(fd)->GetFd(), " :No such channel\r\n");
        }
    }
}
