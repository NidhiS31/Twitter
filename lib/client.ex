defmodule Client do
    use GenServer

    def start_link(userName, numOfUsers, numOfFollowing,isExistingUser) do
       GenServer.start_link(__MODULE__, [userName, numOfUsers, numOfFollowing,isExistingUser])
    end

    @impl true
    def init([userName, numOfUsers, numOfRequests, isExistingUser]) do
        serverPID = elem(Enum.at(:ets.lookup(:serverNode,"Server"),0),1)
        userPID = self()
        registerUser(serverPID, userName, userPID)
        receive do
            {:userRegistered} -> IO.puts("#{userName} is now registered!")
        end
        # randomly pick a tweet from list and use it for a user
        # tweets = getRandomTweet()
        pickRandomUserForTweeting(numOfUsers, numOfRequests, serverPID, userPID) 
        # sendTweets(serverPID, userName, userPID, tweets)

    end

    def getRandomTweet() do
        # list of tweets
        tweetList = ["This is Twitter clone", "I ate a clock yesterday, it was very time-consuming.", "How do prisoners call each other? On their cell phones!", "The light heart lives long."]
        # return a random tweet
        tweets = Enum.random(tweetList)
        tweets
    end

    def getRandomHashtags() do
        hashtagsList = ["#COP5615", "#DOS", "#Twitter", "#Elixir", "#UFlorida", "#GoGators", "#ComputerScience"]
        hashtags = Enum.random(hashtagsList)
        hashtags
    end

    def getTweetsWithHashtags() do
        tweetsWithHashtags = getRandomTweet() <> getRandomHashtags()
        # IO.inspect(tweetsWithHashtags)
        tweetsWithHashtags
    end
    
    def getMentionedUser(numOfUsers) do
        randomUser = "User" <> Integer.to_string(Enum.random(1..numOfUsers))
        mentionUser = "@" <> randomUser
        mentionUser
    end

    # def getTweetsWithMentions(numOfUsers) do
    #     tweetsWithMentions = getRandomTweet() <> getMentions(numOfUsers)
    #     # IO.inspect(tweetsWithHashtags)
    #     tweetsWithMentions
    # end

    # def getMentionedUser(numOfUsers) do
    #     mentionedUser = getMentionedUser(numOfUsers)
    # end

    #Register Account for  new User.
    def registerUser(serverPID, userName, userPID) do
        GenServer.cast(serverPID, {:registerUser,userName,userPID})
    end
    
    def pickRandomUserForTweeting(numOfUsers, numOfRequests, serverPID, userPID) do
        # get a random user from global register
        randomUser = "User" <> Integer.to_string(Enum.random(1..numOfUsers))
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

    def tweetGenerator(numOfRequests, serverPID, userName, userPID) do
        tweets = getRandomTweet()
        sendTweets(serverPID, userName, userPID, numOfRequests, tweets)
        # tweetGenerator(numOfRequests - 1, serverPID, userName, userPID)
    end

    def hashtagTweetGenerator(numOfRequests, serverPID, userName, userPID) do
        hashtagsTweets = getTweetsWithHashtags()
        # IO.inspect(hashtagsTweets)
        sendTweetsWithHashtags(serverPID, userName, userPID, numOfRequests, hashtagsTweets)
    end

    def mentionTweetGenerator(numOfUsers, numOfRequests, serverPID, userName, userPID) do
        mentionedUser = getMentionedUser(numOfUsers)
        tweet = getRandomTweet() <> mentionedUser
        sendTweetsWithMention(serverPID, userName, userPID, numOfRequests, tweet, mentionedUser)
    end

    def getTweetLimit(serverPID, userName) do
        tweetLimit = GenServer.call(serverPID, {:getTweetLimit, userName})
        tweetLimit
    end

    #send tweets
    def sendTweets(serverPID, userName, userPID, numOfRequests, tweets) do
      GenServer.cast(serverPID, {:userTweet, userName, userPID, numOfRequests, tweets})
    end

    def sendTweetsWithHashtags(serverPID, userName, userPID, numOfRequests, tweets) do
        GenServer.cast(serverPID, {:userTweetWithHashtags, userName, userPID, numOfRequests, tweets})
    end

    def sendTweetsWithMention(serverPID, userName, userPID, numOfRequests, tweet, mentionedUser) do
        GenServer.cast(serverPID, {:userTweetWithMention, userName, userPID, numOfRequests, tweet, mentionedUser})
      end
end