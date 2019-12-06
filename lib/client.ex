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
            {:userRegistered} -> IO.puts("#{userName} is now registered!")
        end

        

        followerGenerator(serverPID, userName, numOfUsers, numOfRequests, userPID)        
        usersToDelete = round(Float.ceil(0.1 * numOfUsers))
        deleteUsers(usersToDelete, serverPID, numOfUsers)
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
        tweetsWithHashtags = getRandomTweet() <> getRandomHashtags()
        tweetsWithHashtags
    end
    
    # randomly pick a user to mention in a tweet for a user
    def getMentionedUser(numOfUsers) do
        randomUser = randomUserSelector(numOfUsers)
        mentionUser = "@" <> randomUser
        mentionUser
    end

    #Register Account for  new User.
    def registerUser(serverPID, userName, userPID) do
        GenServer.cast(serverPID, {:registerUser,userName,userPID})
    end
    
    #Pick a random user to send tweets
    def pickRandomUserForTweeting(numOfUsers, numOfRequests, serverPID, userPID) do
        # get a random user from global register
        randomUser = randomUserSelector(numOfUsers)
        # randomUser = elem(Enum.at(:ets.lookup(:globalRegister, :userName),randomPosition),0)
        # Process.sleep(1000)
         if(getTweetLimit(serverPID, randomUser) > numOfRequests) do
            # if user reached tweet limit pick another user
            pickRandomUserForTweeting(numOfUsers, numOfRequests, serverPID, userPID)
            # Process.sleep(1000)
        end
        tweetGenerator(numOfRequests, serverPID, randomUser, userPID)
        hashtagTweetGenerator(numOfRequests, serverPID, randomUser, userPID)
        mentionTweetGenerator(numOfUsers, numOfRequests, serverPID, randomUser, userPID)
    end

    #generate tweets 
    def tweetGenerator(numOfRequests, serverPID, userName, userPID) do
        tweets = getRandomTweet()
        sendTweets(serverPID, userName, userPID, numOfRequests, tweets)
        # tweetGenerator(numOfRequests - 1, serverPID, userName, userPID)
    end

    #generate tweets conatining hashtags
    def hashtagTweetGenerator(numOfRequests, serverPID, userName, userPID) do
        hashtagsTweets = getTweetsWithHashtags()
        # IO.inspect(hashtagsTweets)
        sendTweetsWithHashtags(serverPID, userName, userPID, numOfRequests, hashtagsTweets)
    end

    #generate tweets conatining mentions
    def mentionTweetGenerator(numOfUsers, numOfRequests, serverPID, userName, userPID) do
        mentionedUser = getMentionedUser(numOfUsers)
        tweet = getRandomTweet() <> mentionedUser
        sendTweetsWithMention(serverPID, userName, userPID, numOfRequests, tweet, mentionedUser)
    end

    #get the tweetlimit which should be less than the numOfRequests
    def getTweetLimit(serverPID, userName) do
        tweetLimit = GenServer.call(serverPID, {:getTweetLimit, userName})
        tweetLimit
    end

    #send tweets
    def sendTweets(serverPID, userName, userPID, numOfRequests, tweets) do
      GenServer.cast(serverPID, {:userTweet, userName, userPID, numOfRequests, tweets})
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

    def followerGenerator(serverPID, userName, numOfUsers, numOfRequests, userPID) when numOfRequests == 0 do        
        pickRandomUserForTweeting(numOfUsers, numOfRequests, serverPID, userPID) 
    end

    #generate followers for a user
    def addFollowers(userName, serverPID, numOfUsers) do
        followerName = getFollower(userName, numOfUsers)
        # IO.inspect(followerName)
        GenServer.cast(serverPID, {:addToFollowers, userName, followerName})
    end

    def getFollower(userName, numOfUsers) do
        followerString = randomUserSelector(numOfUsers)
        followerName =  if userName == followerString do
                            getFollower(userName, numOfUsers)
                        else
                            followerString
                        end
        # IO.inspect(followerName)
        followerName        
    end

    def deleteUsers(usersToDelete, serverPID, numOfUsers) do        
        # when usersToDelete > 0
        deleteUserName = randomUserSelector(numOfUsers)
        GenServer.cast(serverPID, {:deleteRandomUsers, deleteUserName, usersToDelete})
    end
    def randomUserSelector(numOfUsers) do
        randomNumber = Enum.random(1..numOfUsers)
        randomString = "User" <> Integer.to_string(randomNumber)
        randomString
    end
end