### Fill in missing release dates using Wikipedia infobox data
#Input: games_w_keywords.csv
#Outputs: games_w_rldates.csv

import pandas as pd
import re
import wptools
from serpapi.google_search_results import GoogleSearchResults
import pdb, traceback, sys

def main():
  GoogleSearchResults.SERP_API_KEY = "3d42b081b7807b6f9c6a37504613b07a02f5f9b00b6aed88731ff9483e161bc2"
  months = {'January':1, 'February':2, 'March':3, 'April':4, 'May':5, 'June':6, 'July':7,'August':8,'September':9, 'October':10, 'November':11,'December':12}
  platform_altnames = {'PS3':'PlayStation 3', 'PS4':'PlayStation 4', 'PSP':'PlayStation Portable'}

  sales = pd.read_csv("games_w_keywords.csv")
  sales.reset_index(drop=True, inplace=True)
  release_date = []
  new_sales = pd.DataFrame(columns=sales.columns)
  for g, game in enumerate(sales['Name']):
    try:
      page = wptools.page(game)
      if 'released' in page.get_parse().infobox:
        date_str = page.get_parse().infobox['released']
      else:
        date_str = page.get_parse().infobox['release']
    except Exception:  #wiki page not found or non-game wiki page detected
      try:
        google_qry = game + ' site:wikipedia.org'
        client = GoogleSearchResults({"q": google_qry, "serp_api_key": GoogleSearchResults.SERP_API_KEY})
        site = client.get_dict()['organic_results'][0]['link']
        wiki_qry = site.split('/')[-1]
        page = wptools.page(wiki_qry)
        if 'released' in page.get_parse().infobox:
          date_str = page.get_parse().infobox['released']
        else:
          date_str = page.get_parse().infobox['release']
      except Exception:  #no results found or wiki infobox has no 'release' section
        continue
    date_str_split = date_str.split("|")

    #preprocess to narrow down dates to right platform and right region
    for i, q in enumerate(date_str_split):
      if sales['Platform'][g] in ''.join(date_str_split[:i]):
          date_str_split = date_str_split[i:]
          break
      elif sales['Platform'][g] in platform_altnames:
        if platform_altnames[sales['Platform'][g]] in ''.join(date_str_split[:i]):
          date_str_split = date_str_split[i:]
          break

    for i, q in enumerate(date_str_split):
      if 'NA' in date_str_split[i-1] or 'WW' in date_str_split[i-1]:
          date_str_split = [date_str_split[i]]
          break

    for i, q in enumerate(date_str_split):
      if 'JP' in date_str_split[i-1]:
        continue
      day, month, year = '', '', ''
      date = date_str_split[i].split()
      for mem in date:
          mem= re.sub('[(){}<>,]', '', mem)
          if mem in months:
              month = str(months[mem])
          if mem.isnumeric():
              if int(mem) < 32:
                  day = str(mem)
              else:
                  year = str(mem)
      try:
        int(year)
      except Exception:
        continue
      if (day != '' and month != '' and int(year) == int(sales['Year_of_Release'][g])):
          break
    try:
      int(year)
    except Exception:
      continue
    if day == '' or month == '' or year == '' or int(year) != int(sales['Year_of_Release'][g]):
      continue
    if month == '12' and int(year) == 2016:
      continue
    rd = month + '/' + day + '/' + year
    release_date.append(rd)
    new_sales = new_sales.append(sales.iloc[[g]])
  
  new_sales['release date'] = release_date
  f = open('games_w_rldates.csv', "w+")
  new_sales.to_csv('games_w_rldates.csv', index=False)

if __name__ == "__main__":
  try:
    main()
  except:
    type, value, tb = sys.exc_info()
    traceback.print_exc()
    pdb.post_mortem(tb)
