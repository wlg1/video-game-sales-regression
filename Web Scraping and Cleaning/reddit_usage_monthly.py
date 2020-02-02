import pickle, calendar
import matplotlib.pyplot as plt

day_to_count = pickle.load( open( "day_to_count.p", "rb" ) )
month_names = [calendar.month_abbr[month] for month in range(1, 13)]
monthly_usage = [0]*12
years = ['2010', '2011', '2012', '2013', '2014', '2015', '2016']
for year in years:
  for date, count in day_to_count.items():
    if date.split('/')[2] == year:
      month = int(date.split('/')[0]) - 1
      monthly_usage[month] += int(count)

  print(year, monthly_usage)
  fig = plt.figure()
  ax = fig.add_subplot(111)
  ax.bar(month_names, monthly_usage)
  plt.title(str(year) + " Reddit Monthly Activity")
  plt.xlabel('Month')
  plt.ylabel('Activity')
  fig.savefig(year + '_reddit_monthly_usage.png', bbox_inches = "tight")

for date, count in day_to_count.items():
  month = int(date.split('/')[0]) - 1
  monthly_usage[month] += int(count)
print("2010-2016", monthly_usage)
fig = plt.figure()
ax = fig.add_subplot(111)
ax.bar(month_names, monthly_usage)
plt.title("2010 - 2016 Reddit Monthly Activity")
plt.xlabel('Month')
plt.ylabel('Activity')
fig.savefig('2010_to_2016_reddit_monthly_usage.png', bbox_inches = "tight")  #tights prevents label cutoff

"""
counts = list(month_year.values())
fig = plt.figure()
plt.plot(range(len(counts)), counts, '-')
plt.xlabel('Month/Year')
plt.ylabel('# posts')
fig.savefig('num_posts_growth.png')
plt.show()
"""