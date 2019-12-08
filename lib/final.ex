defmodule Final do 

  def main(args) do
    # Create table to maintain server pid for handling Genserver handle calls and casts
    :ets.new(:serverNode, [:set, :public, :named_table])
    # start server
    Task.start(fn -> Server.start_link() end)
    Process.sleep(1000)

    # starting client
    numOfUsers = String.to_integer(Enum.at(args, 0))
    numOfRequests = String.to_integer(Enum.at(args, 1))
    serverPID = elem(Enum.at(:ets.lookup(:serverNode,"Server"),0),1)
    
    #defining global tables
    :ets.new(:globalRegister, [:set, :public, :named_table])
    :ets.new(:timeRegister, [:set, :public, :named_table])

    #function to create new users
    createNewUsers(1,numOfUsers,numOfRequests, serverPID)
    infiniteLoop()
    # Process.sleep(20000)

    #parameters for performance analysis
    timeForTweets = 0
    timeForSubscribedToQueries = 0
    timeForHashtagQueries = 0
    timeForMentionQueries = 0
    performanceParameters(1, numOfUsers, timeForTweets, timeForSubscribedToQueries, timeForHashtagQueries, timeForMentionQueries)
  end

  def performanceParameters(count, numOfUsers, timeForTweets, timeForSubscribedToQueries, timeForHashtagQueries, timeForMentionQueries) when count <= numOfUsers do

    userName = "User" <> Integer.to_string(count)
    if (:ets.lookup(:timeRegister, userName) != []) do
      [timeTuple] = :ets.lookup(:timeRegister, userName)
      timeDetailList = elem(timeTuple,1)
      timeForTweets = timeForTweets + Enum.at(timeDetailList,0)
      timeForSubscribedToQueries = timeForSubscribedToQueries + Enum.at(timeDetailList,1)
      timeForHashtagQueries = timeForHashtagQueries + Enum.at(timeDetailList,2)
      timeForMentionQueries = timeForMentionQueries + Enum.at(timeDetailList,3)    
    
      performanceParameters(count + 1, numOfUsers, timeForTweets, timeForSubscribedToQueries, timeForHashtagQueries, timeForMentionQueries)
    end   
  end

  def performanceParameters(count, numOfUsers, timeForTweets, timeForSubscribedToQueries, timeForHashtagQueries, timeForMentionQueries) do
    userName = "User" <> Integer.to_string(count)
    if (:ets.lookup(:timeRegister, userName) != []) do
      [timeTuple]=:ets.lookup(:timeRegister, userName)
      timeDetailList = elem(timeTuple,1)
      timeForTweets = timeForTweets + Enum.at(timeDetailList,0)
      timeForSubscribedToQueries = timeForSubscribedToQueries + Enum.at(timeDetailList,1)
      timeForHashtagQueries = timeForHashtagQueries + Enum.at(timeDetailList,2)
      timeForMentionQueries = timeForMentionQueries + Enum.at(timeDetailList,3)

      IO.puts "Average time to tweet : #{timeForTweets/numOfUsers} milliseconds"
      IO.puts "Average time for Subscribed To Queries #{timeForSubscribedToQueries/numOfUsers} milliseconds"
      IO.puts "Average time for Hashtag Queries: #{timeForHashtagQueries/numOfUsers} milliseconds"
      IO.puts "Average time for Mentioned Queries : #{timeForMentionQueries/numOfUsers} milliseconds"
    end
  end

  def createNewUsers(userNumber, numOfUsers, numOfRequests, serverPID) when userNumber <= numOfUsers do
    userName = "User" <> Integer.to_string(userNumber)
    userPID = spawn(fn -> Client.start_link(userName, numOfUsers, numOfRequests, false) end)
    :ets.insert(:globalRegister, {userName, userPID})
    userNumber = userNumber + 1
    createNewUsers(userNumber, numOfUsers, numOfRequests, serverPID)
  end

  def createNewUsers(_userNumber, numOfUsers, _numOfRequests, _serverPID) do
    IO.puts("\nAll #{numOfUsers} users registered!\n")
  end

  def infiniteLoop() do
    infiniteLoop()
  end

end
