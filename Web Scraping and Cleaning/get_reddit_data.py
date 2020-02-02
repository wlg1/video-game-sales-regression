### Scrap Reddit posts to obtain game mention and upvote metrics
#Input: games_w_rldates_comb.csv, day_to_count.p
#Outputs: game_mentions_data.csv

import pandas as pd
import requests
import json
import csv
import time
import datetime
import pickle
import re
import pdb, traceback, sys

def getPushshiftData(query, after, before, sub):
  url = 'https://api.pushshift.io/reddit/search/submission/?title='+str(query)+'&size=1000&after='+str(after)+'&before='+str(before)+'&subreddit='+str(sub)
  r = requests.get(url)
  data = json.loads(r.text)
  return data['data']

def collectSubData(query, game_name, subm, subStats):
  subData = list() #list to store data points
  title = subm['title']
  url = subm['url'] 
  author = subm['author']
  sub_id = subm['id']
  score = subm['score']
  created = datetime.datetime.fromtimestamp(subm['created_utc']) #1520561700.0
  numComms = subm['num_comments']
  permalink = subm['permalink']
  
  subData.append((sub_id,title,url,author,score,created,numComms,permalink, query, game_name))
  subStats[sub_id] = subData
  return subStats

def updateSubs_file(subStats):
  filename = 'post_data.csv'
  f = open(filename, "w+")
  with open(filename, 'a', newline='', encoding='utf-8') as file: 
    a = csv.writer(file, delimiter=',')
    headers = ["Post ID","Title","Url","Author","Score","Publish Date","Total No. of Comments","Permalink", "Query", "Game"]
    a.writerow(headers)
    for sub in subStats:
      a.writerow(subStats[sub][0])

def scrap_reddit(game_name, start, end, start_date, end_date, sub, day_to_count, alt_names, subStats, new_row, period):
  count = 0
  date_obj = start_date
  while date_obj != end_date:
    date_obj = (datetime.datetime.strptime(date_obj,"%m/%d/%Y") + datetime.timedelta(days=1)).strftime("%m/%d/%Y")
    count += day_to_count[date_obj]
  
  mentions = 0  #count the number of posts made about game
  upvotes = 0
  queries = alt_names[game_name]
  for query in queries:
    try:
      data = getPushshiftData(query, start, end, sub)
      if data:  # run until all posts have been gathered from the 'start' date up until 'end' date
        while len(data) > 0:
          for submission in data:
            if submission['id'] not in subStats:
              mentions +=1
              upvotes += int(submission['score'])
              subStats = collectSubData(query, game_name, submission, subStats)
          # Calls getPushshiftData() with the created date of the last submission
          #This loop is needed as Reddit limits API calls to avoid overloading the server.
          new_start = data[-1]['created_utc']
          data = getPushshiftData(query, new_start, end, sub)
      print(game_name, query, mentions, period)
    except:
      continue

  new_row['mentions ' + period] = mentions
  new_row['total posts ' + period] = count
  new_row['normalized mentions ' + period] = round(mentions / count, 15)
  new_row['upvotes ' + period] = upvotes
  return new_row  #end of scrap_reddit()

def main():
  day_to_count = pickle.load( open( "day_to_count.p", "rb" ) )
  day_to_count['09/29/2015'] = 1000
  sub='gaming'
  sales = pd.read_csv("games_w_rldates_comb.csv")
  sales["Year_of_Release"] = pd.to_numeric(sales["Year_of_Release"]) #NaNs will be converted into int NaNs
  games = sales['Name']

  f = open('game_mentions_data.csv', "w+")
  file = open('game_mentions_data.csv', 'a', newline='', encoding='utf-8')
  new_data = csv.writer(file, delimiter=',')
  header = sales.columns.values.tolist()
  header += ['mentions before', 'total posts before', 'normalized mentions before', 'upvotes before',
            'mentions after', 'total posts after', 'normalized mentions after', 'upvotes after']
  new_data.writerow(header)

  alt_names = {}
  for i, alts in enumerate(sales['keywords']):
    alt_names[games[i]] = alts.split(',')
  
  subStats = {}
  for g, game_name in enumerate(games):
    #find the game's release date, and get the month before it to the day before release
    date_lst = sales['release date'][g].split('/')
    if '' in date_lst or len(date_lst) != 3:
      continue
    if len(date_lst[0]) == 1:
      month = '0' + date_lst[0]
    else:
      month = date_lst[0]
    if len(date_lst[1]) == 1:
      day = '0' + date_lst[1]
    else:
      day = date_lst[1]
    year = date_lst[2]

    #mentions 28 days BEFORE release
    #convert year, month, day to unix timestamp
    end_date =  month +'/' + day+ '/' + year
    end = int(time.mktime(datetime.datetime.strptime(end_date, "%m/%d/%Y").timetuple()))
    start_date = (datetime.datetime.strptime(end_date,"%m/%d/%Y") - datetime.timedelta(days=28)).strftime("%m/%d/%Y")
    start = int(time.mktime(datetime.datetime.strptime(start_date, "%m/%d/%Y").timetuple()))
    new_row = sales.loc[[g]]
    new_row = scrap_reddit(game_name, start, end, start_date, end_date, sub, 
                                day_to_count, alt_names, subStats, new_row, 'before')

    #mentions 28 days AFTER release
    start_date = end_date
    start = end
    end_date = (datetime.datetime.strptime(end_date,"%m/%d/%Y") + datetime.timedelta(days=28)).strftime("%m/%d/%Y")
    end = int(time.mktime(datetime.datetime.strptime(end_date, "%m/%d/%Y").timetuple()))
    new_row = scrap_reddit(game_name, start, end, start_date, end_date, sub, 
                                day_to_count, alt_names, subStats, new_row, 'after')

    new_data.writerow(new_row.values.tolist()[0])

  updateSubs_file(subStats)

if __name__ == "__main__":
  try:
    main()
  except:
    type, value, tb = sys.exc_info()
    traceback.print_exc()
    pdb.post_mortem(tb)
