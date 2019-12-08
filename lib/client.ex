defmodule Client do
use GenServer
#Start client PIDs
def start_link(userName, numOfUsers, numOfFollowing,isExistingUser) do
    GenServer.start_link(__MODULE__, [userName, numOfUsers, numOfFollowing,isExistingUser])
end

#handle client functions after starting them
@impl true
def init([userName, numOfUsers, numOfRequests, isExistingUser]) do
    serverPID = elem(Enum.at(:ets.lookup(:serverNode,"Server"),0),1)
    userPID = self()
    registerUser(serverPID, userName, userPID)
    receive do
        {:userRegistered, userName} -> IO.puts("#{userName} is now registered!")
    end
    
    usersToDelete = round(Float.ceil(0.1 * numOfUsers))
    numOfUsersToDisconnect = round(Float.ceil(0.4 * numOfUsers))

    twitterHandler(serverPID, userName, numOfUsers, numOfRequests, userPID, usersToDelete, numOfUsersToDisconnect)

end

def twitterHandler(serverPID, userName, numOfUsers, numOfRequests, userPID, usersToDelete, numOfUsersToDisconnect) do
    followerGenerator(serverPID, userName, numOfUsers, numOfRequests, userPID)
    tweetForUser(numOfUsers, numOfRequests, serverPID, userPID)
    tweetWithHashtags(numOfUsers, numOfRequests, serverPID, userPID)
    tweetWithMentions(numOfUsers, numOfRequests, serverPID, userPID)
    sendRetweets(serverPID, numOfUsers, userPID)
    queryForSubscribedTo(numOfUsers, serverPID)
    queryHashTag(serverPID, numOfUsers)
    queryMention(serverPID, numOfUsers)
    getLiveView(serverPID, numOfUsers)
    deleteUsers(usersToDelete, serverPID, numOfUsers)
    disconnectUsers(numOfUsersToDisconnect, serverPID, numOfUsers)
    reconnectUsers(serverPID, numOfUsers)
end

# randomly pick a tweet from tweest list and use it for a user
def getRandomTweet() do
    # list of tweets
    tweetList = ["This is Twitter clone", "I ate a clock yesterday, it was very time-consuming.", "How do prisoners call each other? On their cell phones!", "The light heart lives long."]
    tweets = Enum.random(tweetList)
    tweets
end

# randomly pick a hashtag from hashtags list and use it for a user
def getRandomHashtags() do
    hashtagsList = ["#COP5615", "#DOS", "#Twitter", "#Elixir", "#UFlorida", "#GoGators", "#ComputerScience"]
    hashtags = Enum.random(hashtagsList)
    hashtags
end

#get a tweet containing hashtag in it
def getTweetsWithHashtags() do
    space = " "
    tweetsWithHashtags = getRandomTweet() <> space <> getRandomHashtags()
    # IO.inspect(tweetsWithHashtags)
    tweetsWithHashtags
end

def getMentionedUser(numOfUsers) do
    randomUser = getRandomUser(numOfUsers)
    space = " "
    mentionUser = space <> "@" <> randomUser
    mentionUser
end

def getRandomUser(numOfUsers) do
    randomUser = "User" <> Integer.to_string(Enum.random(1..numOfUsers))
    randomUser
end


def tweetForUser(numOfUsers, numOfRequests, serverPID, userPID) do
    # get a random user from global register
    randomUser = getRandomUser(numOfUsers)
        if(getTweetLimit(serverPID, randomUser) > numOfRequests) do
        # if user reached tweet limit pick another user
        tweetForUser(numOfUsers, numOfRequests, serverPID, userPID)
    end
    tweetGenerator(numOfRequests, serverPID, randomUser, userPID)
end

def tweetWithHashtags(numOfUsers, numOfRequests, serverPID, userPID) do
    randomUser = getRandomUser(numOfUsers)
    if(getTweetLimit(serverPID, randomUser) > numOfRequests) do
        # if user reached tweet limit pick another user
        tweetWithHashtags(numOfUsers, numOfRequests, serverPID, userPID)
    end
    hashtagTweetGenerator(numOfRequests, serverPID, randomUser, userPID)
end

def tweetWithMentions(numOfUsers, numOfRequests, serverPID, userPID) do
    randomUser = getRandomUser(numOfUsers)
    if(getTweetLimit(serverPID, randomUser) > numOfRequests) do
        # if user reached tweet limit, pick another user
        tweetWithMentions(numOfUsers, numOfRequests, serverPID, userPID)
    end
    mentionTweetGenerator(numOfUsers, numOfRequests, serverPID, randomUser, userPID)
end

def tweetGenerator(numOfRequests, serverPID, userName, userPID) do
    tweets = getRandomTweet()
    sendTweets(serverPID, userName, userPID, numOfRequests, tweets)
    receive do
        {:userTweeted, tweet} -> {:ok, tweet}
            # IO.inspect("#{userName} tweeted: #{tweets}")
    end
end

def hashtagTweetGenerator(numOfRequests, serverPID, userName, userPID) do
    hashtagsTweets = getTweetsWithHashtags()
    # IO.inspect(hashtagsTweets)
    sendTweetsWithHashtags(serverPID, userName, userPID, numOfRequests, hashtagsTweets)
    receive do
        {:userTweetedWithHashTags, tweet} -> {:ok, tweet}
    end
end

def mentionTweetGenerator(numOfUsers, numOfRequests, serverPID, userName, userPID) do
    mentionedUser = getMentionedUser(numOfUsers)
    tweet = getRandomTweet() <> mentionedUser
    sendTweetsWithMention(serverPID, userName, userPID, numOfRequests, tweet, mentionedUser)
    receive do
        {:userTweetedWithMentions, tweet} -> {:ok, tweet}
    end
end

def sendRetweets(serverPID, numOfUsers, userPID)  do
userName = getRandomUser(numOfUsers)
#Check if useer is alive?
retweetDetail = getRetweet(serverPID, userName)
if(!Enum.empty?(retweetDetail)) do
    retweet = Enum.at(retweetDetail, 1)
    retweetOfUser = Enum.at(retweetDetail, 0)
    GenServer.cast(serverPID, {:sendRetweets, userName, retweet, retweetOfUser, userPID})
else
    sendRetweets(serverPID, numOfUsers, userPID)
end
# if user is not alive - store tweets in another table,
# when user comes back alive, get the user's tweets and display them
end

def getRetweet(serverPID, userName) do
retweetDetail = GenServer.call(serverPID, {:getTweetToRetweet, userName})
retweetDetail
end

#Register Account for  new User.
def registerUser(serverPID, userName, userPID) do
    GenServer.cast(serverPID, {:registerUser,userName,userPID})
end

#send tweets
def sendTweets(serverPID, userName, userPID, numOfRequests, tweets) do
    GenServer.cast(serverPID, {:userTweet, userName, userPID, numOfRequests, tweets})
end

    #get the tweetlimit which should be less than the numOfRequests
def getTweetLimit(serverPID, userName) do
    tweetLimit = GenServer.call(serverPID, {:getTweetLimit, userName})
    tweetLimit
end

#send tweets with hashtags
def sendTweetsWithHashtags(serverPID, userName, userPID, numOfRequests, tweets) do
    GenServer.cast(serverPID, {:userTweetWithHashtags, userName, userPID, numOfRequests, tweets})
end
#send tweets with mentions
def sendTweetsWithMention(serverPID, userName, userPID, numOfRequests, tweet, mentionedUser) do
    GenServer.cast(serverPID, {:userTweetWithMention, userName, userPID, numOfRequests, tweet, mentionedUser})
end

def followerGenerator(serverPID, userName, numOfUsers, numOfRequests, userPID) when numOfRequests > 0 do
    addFollowers(userName, serverPID, numOfUsers)
    followerGenerator(serverPID, userName, numOfUsers, numOfRequests - 1, userPID)
end

def followerGenerator(serverPID, _userName, numOfUsers, numOfRequests, userPID) when numOfRequests == 0 do
end

#generate followers for a user
def addFollowers(userName, serverPID, numOfUsers) do
    followerName = getFollower(userName, numOfUsers)
    # IO.inspect(followerName)
    GenServer.cast(serverPID, {:addToFollowers, userName, followerName})
end

def getFollower(userName, numOfUsers) do
    followerString = getRandomUser(numOfUsers)
    followerName =  if userName == followerString do
                        getFollower(userName, numOfUsers)
                    else
                        followerString
                    end
    # IO.inspect(followerName)
    followerName
end

def deleteUsers(usersToDelete, serverPID, numOfUsers) do
    deleteUserName = getRandomUser(numOfUsers)
    GenServer.cast(serverPID, {:deleteRandomUsers, deleteUserName, usersToDelete})
end


def disconnectUsers(numOfUsersToDisconnect, serverPID, numOfUsers) do
    userToDisconnect = getRandomUser(numOfUsers)
    GenServer.cast(serverPID, {:disconnectRandomUsers, userToDisconnect, numOfUsersToDisconnect})
end

def reconnectUsers(serverPID, numOfUsers) do
    userToReconnect = getDisconnectedUser(serverPID, numOfUsers)
    if userToReconnect != " " do
        GenServer.cast(serverPID, {:reconnectUser, userToReconnect})
    end    
end

def getDisconnectedUser(serverPID, numOfUsers) do
    disconnectedUsersList = GenServer.call(serverPID, {:getDisconnectedUsers, numOfUsers})
    disconnectUser =     if !Enum.empty?(disconnectedUsersList) do
                            Enum.random(disconnectedUsersList)
                         else
                            " "
                         end
    disconnectUser
end
#Query for a user you subscribed to
def queryForSubscribedTo(numOfUsers, serverPID) do
    randomUser = getRandomUser(numOfUsers)
    followingList = getFollowingList(serverPID, randomUser)
    randomSubscribedTo =if !Enum.empty?(followingList) do
                            Enum.random(followingList)
                        else
                            ""
                        end
    if randomSubscribedTo != "" do
        getTweetsOfSubscribedTo(serverPID, randomUser, randomSubscribedTo)
    else
        queryForSubscribedTo(numOfUsers, serverPID)
    end
end

@spec getFollowingList(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
def getFollowingList(serverPID, userName) do
    followingUsersList = GenServer.call(serverPID, {:getfollowingUsers, userName})
    followingUsersList
end

def getTweetsOfSubscribedTo(serverPID, userName, userSubscribedTo) do
    GenServer.cast(serverPID, {:getAllTweets, userName, userSubscribedTo})
end

#Query by hashtag
def queryHashTag(serverPID, numOfUsers) do
    #select a random hashtag and call the server to fetch all the tweets with hashtags
    randomHashTag = getRandomHashtags()
    GenServer.cast(serverPID, {:queryHashTag, randomHashTag, numOfUsers})
end

#Query by Mention
def queryMention(serverPID, numOfUsers) do
    randomUserName = getRandomUser(numOfUsers)
    GenServer.cast(serverPID, {:queryMention, randomUserName, numOfUsers})
end

def getLiveView(serverPID, numOfUsers) do
    userName = getRandomUser(numOfUsers)
    disconnectedUsersList = getDisconnectedUserList(serverPID, numOfUsers)
    if (!Enum.member?(disconnectedUsersList, userName)) do
        GenServer.cast(serverPID, {:getLiveView, userName})
    end
end

def getDisconnectedUserList(serverPID, numOfUsers) do
    disconnectedUserList = GenServer.call(serverPID, {:getDisconnectedUsers, numOfUsers})
    disconnectedUserList
end
end
