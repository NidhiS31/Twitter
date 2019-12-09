defmodule Server do
use GenServer

def start_link() do
    GenServer.start_link(__MODULE__, :ok)
end

@impl true
def init(:ok) do
    IO.puts "Server Started"
    :ets.insert(:serverNode,{"Server",self()})
    #create a Table to store list of users
    createUserRegister()
    #create a Table to store list of all tweets
    createTweetsRegister()
    #create a Table to store list of all tweets containing hashtags
    createHashtagsRegister()
    #create a Table to store list of all tweets containing mentions
    createMentionsRegister()
    #create a Table to store list of all the users a user is following
    createFollowingRegister()
    #create a Table to store list of all the followers of a user
    createFollowersRegister()
    #create a table for backup of deleted users
    createDeletedUsersRegister()
    #create a table for disconnected users
    createDisconnectedUserRegister()
    state = ""
    {:ok, state}
end

def createUserRegister() do
    :ets.new(:userRegister, [:set, :public, :named_table])
end

def createTweetsRegister() do
    :ets.new(:tweetsRegister, [:set, :public, :named_table])
end

def createHashtagsRegister() do
    :ets.new(:hashtagsRegister, [:set, :public, :named_table])
end

def createMentionsRegister() do
    :ets.new(:mentionsRegister, [:set, :public, :named_table])
end

def createFollowingRegister() do
    :ets.new(:followingRegister, [:set, :public, :named_table])
end

def createFollowersRegister() do
    :ets.new(:followersRegister, [:set, :public, :named_table])
end

def createDeletedUsersRegister() do
    :ets.new(:deletedUsers, [:set, :public, :named_table])
end

def createDisconnectedUserRegister() do
    :ets.new(:disconnectedUsers, [:set, :public, :named_table])
end

@impl true
def handle_cast({:registerUser,userName,userPID}, state) do
    :ets.insert(:userRegister, {userName, userPID})
    :ets.insert(:tweetsRegister, {userName, userPID, 0, []})
    :ets.insert(:hashtagsRegister, {userName, userPID, 0, []})
    :ets.insert(:mentionsRegister, {userName, userPID, 0, []})
    :ets.insert(:followingRegister, {userName, []})
    :ets.insert(:followersRegister, {userName, []})
    :ets.insert(:deletedUsers, {userName, 0})
    :ets.insert(:disconnectedUsers, {userName, nil, 0})
    send(userPID, {:userRegistered, userName})
    {:noreply, state}
end

@impl true
def handle_cast({:userTweet, userName, userPID, tweetLimit, tweets}, state) do
    existingTweets = elem(Enum.at(:ets.lookup(:tweetsRegister,userName),0),3)
    updatedTweets = existingTweets ++ [tweets]
    tweetLimit = tweetLimit + 1
    :ets.insert(:tweetsRegister, {userName, userPID, tweetLimit, updatedTweets})
    IO.inspect("#{userName} tweeted: #{tweets}")
    send(userPID, {:userTweeted, tweets})
    {:noreply, state}
end

@impl true
def handle_cast({:userTweetWithHashtags, userName, userPID, tweetLimit, tweets}, state) do
    existingTweets = elem(Enum.at(:ets.lookup(:hashtagsRegister,userName),0),3)
    updatedTweets = existingTweets ++ [tweets]
    tweetLimit = tweetLimit + 1
    :ets.insert(:hashtagsRegister, {userName, userPID, tweetLimit, updatedTweets})
    IO.inspect("#{userName} tweeted with Hashtag: #{tweets}")
    send(userPID, {:userTweetedWithHashTags, tweets})
    {:noreply, state}
end

@impl true
def handle_cast({:userTweetWithMention, userName, userPID, tweetLimit, tweets, mentionedUser}, state) do
    existingTweets = elem(Enum.at(:ets.lookup(:mentionsRegister,userName),0),3)
    updatedTweets = existingTweets ++ [tweets]
    tweetLimit = tweetLimit + 1
    :ets.insert(:mentionsRegister, {userName, userPID, tweetLimit, updatedTweets})
    IO.inspect("#{userName} mentioned #{mentionedUser}: #{tweets}")
    send(userPID, {:userTweetedWithMentions, tweets})
    {:noreply, state}
end

@impl true
def handle_cast({:addToFollowers, userName, followerName, userPID}, state) do
    existingFollowers = elem(Enum.at(:ets.lookup(:followersRegister,userName),0),1)
    updatedFollowers =  if(!Enum.member?(existingFollowers, followerName)) do
                            existingFollowers ++ [followerName]
                        else
                            existingFollowers
                        end
    :ets.insert(:followersRegister, {userName, updatedFollowers})
    existingSubscribers = elem(Enum.at(:ets.lookup(:followingRegister,userName),0),1)
    updatedSubscribers =if(!Enum.member?(existingSubscribers, userName)) do
                            existingSubscribers ++ [userName]
                        else
                            existingSubscribers
                        end
    :ets.insert(:followingRegister, {followerName, updatedSubscribers})
    send(userPID, {:followerAdded, followerName})
    {:noreply, state}
end

@impl true
def handle_cast({:deleteRandomUsers, deleteUserName, usersToDelete}, state) do
    existingUser = elem(Enum.at(:ets.lookup(:userRegister,deleteUserName),0),1)
    deleteCounter = elem(Enum.at(:ets.lookup(:deletedUsers, deleteUserName),0),1)
    deleteCounter =  if((existingUser != nil) && deleteCounter <= usersToDelete ) do
        IO.puts("deleting user:")
        IO.inspect(deleteUserName)
        :ets.insert(:userRegister, {deleteUserName, nil})
        :ets.insert(:deletedUsers, {deleteUserName, deleteCounter})
        deleteCounter = deleteCounter + 1
    end
    {:noreply, state}
end

@impl true
def handle_cast({:sendRetweets, userName, retweet, retweetOfUser, userPID}, state) do
    existingTweets = elem(Enum.at(:ets.lookup(:tweetsRegister,userName),0),3)
    updatedTweets = existingTweets ++ [retweet]
    tweetLimit = elem(Enum.at(:ets.lookup(:tweetsRegister,userName),0),2)
    tweetLimit = tweetLimit + 1
    :ets.insert(:tweetsRegister, {userName, userPID, tweetLimit, updatedTweets})
    IO.inspect("#{userName} retweeted: #{retweet} of #{retweetOfUser}")
    {:noreply, state}
end

#Server call for querying using hashtag
@impl true
def handle_cast({:queryHashTag, randomHashTag, numOfUsers}, state) do
    IO.inspect("Tweets with #{randomHashTag} are:")
    Enum.each(1..numOfUsers, fn x ->
        userName = "User"<>Integer.to_string(x)
        listOfTweets = elem(Enum.at(:ets.lookup(:hashtagsRegister, userName),0),3)
        if !Enum.empty?(listOfTweets) do
            patternMatcher = Enum.at(Tuple.to_list(Regex.compile(randomHashTag)), 1)
            Enum.each(listOfTweets, fn tweet ->
                if(String.match?(tweet, patternMatcher)) do
                    IO.inspect(tweet)
                end
            end)
        end
    end)
    {:noreply, state}
end

#Server call for querying using mention
@impl true
def handle_cast({:queryMention, mentionedUserName, numOfUsers, userPID}, state) do
    IO.inspect("Tweets in which @#{mentionedUserName} is mentioned are:")
    mentionedUser = "@" <> mentionedUserName
    Enum.each(1..numOfUsers, fn x ->
        userName = "User"<>Integer.to_string(x)
        listOfTweetsTuple = :ets.lookup(:mentionsRegister, userName)
        if(listOfTweetsTuple != []) do
            listOfTweets = elem(Enum.at(listOfTweetsTuple,0),3)
            if !Enum.empty?(listOfTweets) do
            patternMatcher = Enum.at(Tuple.to_list(Regex.compile(mentionedUser)), 1)
            Enum.each(listOfTweets, fn tweet ->
                if(String.match?(tweet, patternMatcher)) do
                    IO.inspect("#{mentionedUserName} was mentioned by #{userName} in tweet: #{tweet}")
                end
            end)
        end
    end
    end)
    send(userPID, {:userMentioned, mentionedUser})
    {:noreply, state}
end

@impl true
def handle_cast({:getAllTweets, userName, userSubscribedTo, userPID}, state) do
    followingTweetsList = elem(Enum.at(:ets.lookup(:tweetsRegister, userSubscribedTo),0),3)
    IO.puts("The tweets of #{userSubscribedTo} as Queried by #{userName}")
    if !Enum.empty?(followingTweetsList) do
        Enum.each(followingTweetsList, fn tweets ->
                    IO.puts(tweets) end)
    else
        IO.puts("There are no Tweets by #{userSubscribedTo}")
    end
    send(userPID, {:queryTweetSubscribedTo, userName, userSubscribedTo})
    {:noreply, state}
end

@impl true
def handle_cast({:reconnectUser, userToReconnect, userPID}, state) do
    reconnectUserTuple = :ets.lookup(:disconnectedUsers, userToReconnect)
    reconnectUserPID = if (reconnectUserTuple != []) do
        reconnectUserPID = elem(Enum.at(reconnectUserTuple,0),1)
        reconnectUserPID
    else
        nil
    end
    :ets.insert(:userRegister, {userToReconnect, reconnectUserPID})
    :ets.delete(:disconnectedUsers, userToReconnect)
    IO.inspect("#{userToReconnect} has been Reconnected!!")
    send(userPID, {:reconnectedUser, userToReconnect})
    {:noreply, state}
end

@impl true
def handle_cast({:getLiveView, userName, userPID}, state) do
    tweets = elem(Enum.at(:ets.lookup(:tweetsRegister,userName),0),3)
    tweets = tweets ++ elem(Enum.at(:ets.lookup(:hashtagsRegister,userName),0),3)
    tweets = tweets ++ elem(Enum.at(:ets.lookup(:mentionsRegister,userName),0),3)
    IO.puts("_________________________________________LIVE VIEW of #{userName}_________________________________________")
    Enum.each(tweets, fn tweet -> IO.puts(tweet) end)
    IO.puts("____________________________________________________________________________________________________")
    send(userPID, {:liveView, userName})
    {:noreply, state}
end

@impl true
def handle_cast({:disconnectRandomUsers, userToDisconnect, numOfUsersToDisconnect, userPID}, state) do
    activeUserTuple = :ets.lookup(:userRegister,userToDisconnect)
    activeUserPID = if (activeUserTuple != []) do
                        activeUserPID = elem(Enum.at(activeUserTuple,0),1)
                        activeUserPID
                    else
                        []
                    end
    disconnectedUserTuple = :ets.lookup(:disconnectedUsers, userToDisconnect)
    disconnectCounter = if (disconnectedUserTuple != []) do
                            disconnectCounter = elem(Enum.at(disconnectedUserTuple,0),2)
                            disconnectCounter
                        else
                            0
                        end

    disconnectCounter = if((activeUserPID != nil) && disconnectCounter <= numOfUsersToDisconnect ) do
                            :ets.insert(:disconnectedUsers, {userToDisconnect, activeUserPID, disconnectCounter})
                            :ets.insert(:userRegister, {userToDisconnect, nil})
                            IO.puts("#{userToDisconnect} is now Disconnected!!")
                            disconnectCounter = disconnectCounter + 1
                            disconnectCounter
                        end
    send(userPID, {:userDisconnected, userToDisconnect})
    {:noreply, state}
end

@impl true
def handle_cast({:addToZipfFollowers, userName, userFollowers, userPID}, state) do
    if (userFollowers != nil or userFollowers != []) do
        :ets.insert(:followersRegister, {userName, userFollowers})
        Enum.each(userFollowers, fn(follower) ->
            currentFollowingTuple = :ets.lookup(:followingRegister,follower)
            if currentFollowingTuple != [] do
                currentFollowingList = elem(Enum.at(currentFollowingTuple, 0),1)
                updatedFollowingList =  if(!Enum.member?(currentFollowingList, userName)) do
                    currentFollowingList ++ [userName]
                else
                    currentFollowingList
                end

                :ets.insert(:followingRegister, {follower, updatedFollowingList})
            end
        end)
    end
    send(userPID, {:zipf, userName, userFollowers})
    {:noreply, state}
end

@impl true
def handle_call({:isExistingUser, userName}, _from, state) do
    userTuple = :ets.lookup(:userRegister,userName)
    check = if(userTuple != []) do
     flag = elem(Enum.at(userTuple, 0),0)
     check = if (flag != nil or length(flag) != 0) do
         true
     else
        false
     end
     check
    end
     {:reply, check, state}
end

@impl true
def handle_call({:getfollowingUsers, userName, userPID}, _from, state) do
    followingUsersList = elem(Enum.at(:ets.lookup(:followingRegister,userName),0),1)
    send(userPID, {:gettingFollowerList, userName})
    {:reply, followingUsersList, state}
end

@impl true
def handle_call({:getTweetToRetweet, userName}, _from, state) do
    followingList = elem(Enum.at(:ets.lookup(:followingRegister,userName),0),1)
    randomFollowingUser =   if !Enum.empty?(followingList) do
                                Enum.random(followingList)
                            else
                                ""
                            end
    followingTweetsList =   if String.length(randomFollowingUser) != 0 do
                                elem(Enum.at(:ets.lookup(:tweetsRegister,randomFollowingUser),0),3)
                            else
                                []
                            end
    retweet =   if(!Enum.empty?(followingTweetsList)) do
                    randomRetweet = Enum.random(followingTweetsList)
                retweet =   if String.length(randomRetweet) != 0 do
                                 [randomFollowingUser] ++ [randomRetweet]
                            else
                                []
                            end
                retweet
    else
        retweet = []
        retweet
    end
    {:reply, retweet, state}
end


@impl true
def handle_call({:getTweetLimit, userName}, _from, state) do
    tweetTuple = :ets.lookup(:tweetsRegister,userName)
    tweetLimit =    if (tweetTuple != []) do
                        tweetLimit = elem(Enum.at(tweetTuple,0),2)
                        tweetLimit
                    end
    {:reply, tweetLimit, state}
end


@impl true
def handle_call({:getDisconnectedUsers, numOfUsers}, _from, state) do
    listOfDisconnectedUsers = getListOfDisconnectedUsers(1, numOfUsers, [])
    listOfDisconnectedUsers =   if (!Enum.empty?(listOfDisconnectedUsers)) do
                                    listOfDisconnectedUsers
                                else
                                    []
                                end
    {:reply, listOfDisconnectedUsers, state}
end

def getListOfDisconnectedUsers(startValue, numOfUsers, disConnectedList) when startValue <= numOfUsers do
    userName = "User" <> Integer.to_string(startValue)
    disconnectedTuple = :ets.lookup(:disconnectedUsers, userName)
    disConnectedList =  if (!Enum.empty?(disconnectedTuple)) do
    disConnectedList =  if (elem(Enum.at(disconnectedTuple,0),1) != nil) do
                            disconnectedUser = elem(Enum.at(disconnectedTuple,0),0)
                            disConnectedList =  disConnectedList ++ [disconnectedUser]
                            disConnectedList
                        else
                            disConnectedList
                        end
                        disConnectedList
                    else
                        disConnectedList
                    end

    getListOfDisconnectedUsers(startValue+1, numOfUsers, disConnectedList)

end

def getListOfDisconnectedUsers(startValue, numOfUsers, disConnectedList) when startValue > numOfUsers do
    disConnectedList
end

end
