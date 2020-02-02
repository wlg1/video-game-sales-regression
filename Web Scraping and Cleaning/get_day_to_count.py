import pandas as pd
import requests
import json
import csv
import time
import datetime
from dateutil.relativedelta import *
import pickle
import matplotlib.pyplot as plt
import pdb, traceback, sys

#test if # posts changes for each month over time

def getPushshiftData(query, after, before, sub):
  url = 'https://api.pushshift.io/reddit/search/submission/?title='+str(query)+'&size=1000&after='+str(after)+'&before='+str(before)+'&subreddit='+str(sub)
  r = requests.get(url)
  data = json.loads(r.text)
  return data['data']

day_to_count = {}
sub='gaming'
start_date = '12/01/2009'
while start_date != '01/02/2017':  
  start = int(time.mktime(datetime.datetime.strptime(start_date, "%m/%d/%Y").timetuple()))

  #it's not inclusive of end date; test this by setting end = start, and seeing it returns 0 posts
  #t = datetime.datetime.strptime(start_date,"%m/%d/%Y") + relativedelta(months=+1)
  end_date = (datetime.datetime.strptime(start_date,"%m/%d/%Y") + datetime.timedelta(days=1)).strftime("%m/%d/%Y")
  end = int(time.mktime(datetime.datetime.strptime(end_date, "%m/%d/%Y").timetuple()))

  count = 0
  ids = []
  try:
    data = getPushshiftData('', start, end, sub)
  except:
    data = []
    continue
  if data:  # run until all posts have been gathered from the 'start' date up until 'end' date
    while len(data) > 0:
      for submission in data:
        if submission['id'] not in ids:
          ids.append(submission['id'])
          count += 1
      new_start = data[-1]['created_utc']
      data = getPushshiftData('', new_start, end, sub)
  day_to_count[start_date] = count
  print(start_date, count)

  start_date = (datetime.datetime.strptime(start_date,"%m/%d/%Y") + datetime.timedelta(days=1)).strftime("%m/%d/%Y")

pickle.dump( day_to_count, open( "day_to_count.p", "wb" ) )