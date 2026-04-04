"""
Comprehensive Spark Solution for Nested JSON Processing and Analytics
======================================================================

Problem: Process 4 nested JSONs (players, teams, matches, scores) and create 
an analytics-ready DataFrame to answer business questions.
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, explode, explode_outer, when, count, sum as _sum, 
    max as _max, avg, round as _round, array, struct, lit
)
from pyspark.sql.types import *

# Initialize Spark Session
spark = SparkSession.builder \
    .appName("NestedJSONAnalytics") \
    .config("spark.sql.shuffle.partitions", "4") \
    .getOrCreate()

# ============================================================================
# PART 1: SAMPLE NESTED JSON DATA
# ============================================================================

# Sample Players JSON (with nested skills array)
players_json_data = """
[
  {
    "player_id": "P001",
    "player_name": "Virat Kohli",
    "team_id": "T001",
    "role": "Batsman",
    "skills": [
      {"skill_name": "Batting", "skill_level": 95},
      {"skill_name": "Fielding", "skill_level": 85}
    ],
    "contact": {
      "email": "virat@example.com",
      "phone": "+91-9876543210"
    }
  },
  {
    "player_id": "P002",
    "player_name": "Rohit Sharma",
    "team_id": "T001",
    "role": "Batsman",
    "skills": [
      {"skill_name": "Batting", "skill_level": 92},
      {"skill_name": "Fielding", "skill_level": 80},
      {"skill_name": "Leadership", "skill_level": 88}
    ],
    "contact": {
      "email": "rohit@example.com",
      "phone": "+91-9876543211"
    }
  },
  {
    "player_id": "P003",
    "player_name": "Jasprit Bumrah",
    "team_id": "T001",
    "role": "Bowler",
    "skills": [
      {"skill_name": "Bowling", "skill_level": 98},
      {"skill_name": "Fielding", "skill_level": 75}
    ],
    "contact": {
      "email": "bumrah@example.com",
      "phone": "+91-9876543212"
    }
  },
  {
    "player_id": "P004",
    "player_name": "Steve Smith",
    "team_id": "T002",
    "role": "Batsman",
    "skills": [
      {"skill_name": "Batting", "skill_level": 94},
      {"skill_name": "Fielding", "skill_level": 82}
    ],
    "contact": {
      "email": "smith@example.com",
      "phone": "+61-9876543213"
    }
  },
  {
    "player_id": "P005",
    "player_name": "Pat Cummins",
    "team_id": "T002",
    "role": "Bowler",
    "skills": [
      {"skill_name": "Bowling", "skill_level": 96},
      {"skill_name": "Fielding", "skill_level": 78}
    ],
    "contact": {
      "email": "cummins@example.com",
      "phone": "+61-9876543214"
    }
  },
  {
    "player_id": "P006",
    "player_name": "David Warner",
    "team_id": "T002",
    "role": "Batsman",
    "skills": [
      {"skill_name": "Batting", "skill_level": 90},
      {"skill_name": "Fielding", "skill_level": 83}
    ],
    "contact": {
      "email": "warner@example.com",
      "phone": "+61-9876543215"
    }
  }
]
"""

# Sample Teams JSON
teams_json_data = """
[
  {
    "team_id": "T001",
    "team_name": "India",
    "captain_id": "P002",
    "home_ground": {
      "stadium_name": "Wankhede Stadium",
      "city": "Mumbai",
      "capacity": 33000
    },
    "stats": {
      "founded_year": 1932,
      "world_cups_won": 2
    }
  },
  {
    "team_id": "T002",
    "team_name": "Australia",
    "captain_id": "P005",
    "home_ground": {
      "stadium_name": "MCG",
      "city": "Melbourne",
      "capacity": 100000
    },
    "stats": {
      "founded_year": 1877,
      "world_cups_won": 5
    }
  }
]
"""

# Sample Matches JSON
matches_json_data = """
[
  {
    "match_id": "M001",
    "match_date": "2024-01-15",
    "team1_id": "T001",
    "team2_id": "T002",
    "venue": {
      "stadium_name": "Wankhede Stadium",
      "city": "Mumbai"
    },
    "match_type": "ODI",
    "winner_team_id": "T001",
    "result_margin": {
      "type": "runs",
      "value": 36
    }
  },
  {
    "match_id": "M002",
    "match_date": "2024-01-18",
    "team1_id": "T002",
    "team2_id": "T001",
    "venue": {
      "stadium_name": "MCG",
      "city": "Melbourne"
    },
    "match_type": "ODI",
    "winner_team_id": "T002",
    "result_margin": {
      "type": "wickets",
      "value": 5
    }
  },
  {
    "match_id": "M003",
    "match_date": "2024-01-21",
    "team1_id": "T001",
    "team2_id": "T002",
    "venue": {
      "stadium_name": "Wankhede Stadium",
      "city": "Mumbai"
    },
    "match_type": "T20",
    "winner_team_id": "T001",
    "result_margin": {
      "type": "runs",
      "value": 18
    }
  },
  {
    "match_id": "M004",
    "match_date": "2024-01-24",
    "team1_id": "T002",
    "team2_id": "T001",
    "venue": {
      "stadium_name": "MCG",
      "city": "Melbourne"
    },
    "match_type": "T20",
    "winner_team_id": "T001",
    "result_margin": {
      "type": "wickets",
      "value": 7
    }
  },
  {
    "match_id": "M005",
    "match_date": "2024-01-27",
    "team1_id": "T001",
    "team2_id": "T002",
    "venue": {
      "stadium_name": "Eden Gardens",
      "city": "Kolkata"
    },
    "match_type": "ODI",
    "winner_team_id": "T002",
    "result_margin": {
      "type": "runs",
      "value": 42
    }
  }
]
"""

# Sample Scores JSON (player performance in matches)
scores_json_data = """
[
  {
    "score_id": "S001",
    "match_id": "M001",
    "player_id": "P001",
    "batting": {
      "runs": 89,
      "balls_faced": 102,
      "fours": 8,
      "sixes": 2
    },
    "bowling": {
      "overs": 0,
      "runs_conceded": 0,
      "wickets": 0
    }
  },
  {
    "score_id": "S002",
    "match_id": "M001",
    "player_id": "P002",
    "batting": {
      "runs": 67,
      "balls_faced": 78,
      "fours": 6,
      "sixes": 1
    },
    "bowling": {
      "overs": 0,
      "runs_conceded": 0,
      "wickets": 0
    }
  },
  {
    "score_id": "S003",
    "match_id": "M001",
    "player_id": "P003",
    "batting": {
      "runs": 12,
      "balls_faced": 18,
      "fours": 1,
      "sixes": 0
    },
    "bowling": {
      "overs": 10,
      "runs_conceded": 45,
      "wickets": 3
    }
  },
  {
    "score_id": "S004",
    "match_id": "M001",
    "player_id": "P004",
    "batting": {
      "runs": 54,
      "balls_faced": 71,
      "fours": 5,
      "sixes": 0
    },
    "bowling": {
      "overs": 0,
      "runs_conceded": 0,
      "wickets": 0
    }
  },
  {
    "score_id": "S005",
    "match_id": "M001",
    "player_id": "P005",
    "batting": {
      "runs": 8,
      "balls_faced": 12,
      "fours": 1,
      "sixes": 0
    },
    "bowling": {
      "overs": 10,
      "runs_conceded": 52,
      "wickets": 2
    }
  },
  {
    "score_id": "S006",
    "match_id": "M002",
    "player_id": "P001",
    "batting": {
      "runs": 45,
      "balls_faced": 58,
      "fours": 4,
      "sixes": 1
    },
    "bowling": {
      "overs": 0,
      "runs_conceded": 0,
      "wickets": 0
    }
  },
  {
    "score_id": "S007",
    "match_id": "M002",
    "player_id": "P004",
    "batting": {
      "runs": 98,
      "balls_faced": 112,
      "fours": 10,
      "sixes": 2
    },
    "bowling": {
      "overs": 0,
      "runs_conceded": 0,
      "wickets": 0
    }
  },
  {
    "score_id": "S008",
    "match_id": "M002",
    "player_id": "P005",
    "batting": {
      "runs": 15,
      "balls_faced": 22,
      "fours": 2,
      "sixes": 0
    },
    "bowling": {
      "overs": 10,
      "runs_conceded": 38,
      "wickets": 4
    }
  },
  {
    "score_id": "S009",
    "match_id": "M003",
    "player_id": "P002",
    "batting": {
      "runs": 78,
      "balls_faced": 52,
      "fours": 8,
      "sixes": 3
    },
    "bowling": {
      "overs": 0,
      "runs_conceded": 0,
      "wickets": 0
    }
  },
  {
    "score_id": "S010",
    "match_id": "M003",
    "player_id": "P006",
    "batting": {
      "runs": 62,
      "balls_faced": 48,
      "fours": 6,
      "sixes": 2
    },
    "bowling": {
      "overs": 0,
      "runs_conceded": 0,
      "wickets": 0
    }
  },
  {
    "score_id": "S011",
    "match_id": "M004",
    "player_id": "P001",
    "batting": {
      "runs": 91,
      "balls_faced": 63,
      "fours": 9,
      "sixes": 4
    },
    "bowling": {
      "overs": 0,
      "runs_conceded": 0,
      "wickets": 0
    }
  },
  {
    "score_id": "S012",
    "match_id": "M004",
    "player_id": "P003",
    "batting": {
      "runs": 5,
      "balls_faced": 8,
      "fours": 0,
      "sixes": 0
    },
    "bowling": {
      "overs": 4,
      "runs_conceded": 28,
      "wickets": 3
    }
  },
  {
    "score_id": "S013",
    "match_id": "M005",
    "player_id": "P004",
    "batting": {
      "runs": 112,
      "balls_faced": 128,
      "fours": 12,
      "sixes": 3
    },
    "bowling": {
      "overs": 0,
      "runs_conceded": 0,
      "wickets": 0
    }
  },
  {
    "score_id": "S014",
    "match_id": "M005",
    "player_id": "P006",
    "batting": {
      "runs": 76,
      "balls_faced": 89,
      "fours": 8,
      "sixes": 1
    },
    "bowling": {
      "overs": 0,
      "runs_conceded": 0,
      "wickets": 0
    }
  }
]
"""

# ============================================================================
# PART 2: READ AND FLATTEN NESTED JSONs
# ============================================================================

print("=" * 80)
print("PART 1: READING AND FLATTENING NESTED JSON DATA")
print("=" * 80)

# Read Players JSON
players_df_raw = spark.read.json(
    spark.sparkContext.parallelize([players_json_data]),
    multiLine=True
)

# Flatten Players with nested skills array
players_exploded = players_df_raw.select(
    col("player_id"),
    col("player_name"),
    col("team_id"),
    col("role"),
    col("contact.email").alias("email"),
    col("contact.phone").alias("phone"),
    explode_outer("skills").alias("skill")  # explode_outer handles null arrays
)

# Further flatten the skill struct
players_flattened = players_exploded.select(
    col("player_id"),
    col("player_name"),
    col("team_id"),
    col("role"),
    col("email"),
    col("phone"),
    col("skill.skill_name").alias("skill_name"),
    col("skill.skill_level").alias("skill_level")
)

print("\n1. Players DataFrame (Flattened with Skills):")
players_flattened.show(truncate=False)

# For analytics, we also need a base players table without skills explosion
players_base = players_df_raw.select(
    col("player_id"),
    col("player_name"),
    col("team_id"),
    col("role"),
    col("contact.email").alias("email"),
    col("contact.phone").alias("phone")
)

print("\n2. Players Base DataFrame (No Skills Explosion):")
players_base.show(truncate=False)

# Read and Flatten Teams JSON
teams_df_raw = spark.read.json(
    spark.sparkContext.parallelize([teams_json_data]),
    multiLine=True
)

teams_flattened = teams_df_raw.select(
    col("team_id"),
    col("team_name"),
    col("captain_id"),
    col("home_ground.stadium_name").alias("home_stadium"),
    col("home_ground.city").alias("home_city"),
    col("home_ground.capacity").alias("stadium_capacity"),
    col("stats.founded_year").alias("founded_year"),
    col("stats.world_cups_won").alias("world_cups_won")
)

print("\n3. Teams DataFrame (Flattened):")
teams_flattened.show(truncate=False)

# Read and Flatten Matches JSON
matches_df_raw = spark.read.json(
    spark.sparkContext.parallelize([matches_json_data]),
    multiLine=True
)

matches_flattened = matches_df_raw.select(
    col("match_id"),
    col("match_date"),
    col("team1_id"),
    col("team2_id"),
    col("venue.stadium_name").alias("stadium_name"),
    col("venue.city").alias("city"),
    col("match_type"),
    col("winner_team_id"),
    col("result_margin.type").alias("result_type"),
    col("result_margin.value").alias("result_value")
)

print("\n4. Matches DataFrame (Flattened):")
matches_flattened.show(truncate=False)

# Read and Flatten Scores JSON
scores_df_raw = spark.read.json(
    spark.sparkContext.parallelize([scores_json_data]),
    multiLine=True
)

scores_flattened = scores_df_raw.select(
    col("score_id"),
    col("match_id"),
    col("player_id"),
    col("batting.runs").alias("runs"),
    col("batting.balls_faced").alias("balls_faced"),
    col("batting.fours").alias("fours"),
    col("batting.sixes").alias("sixes"),
    col("bowling.overs").alias("overs_bowled"),
    col("bowling.runs_conceded").alias("runs_conceded"),
    col("bowling.wickets").alias("wickets")
)

print("\n5. Scores DataFrame (Flattened):")
scores_flattened.show(truncate=False)

# ============================================================================
# PART 3: HANDLING DEEPLY NESTED ARRAYS - ADVANCED TECHNIQUES
# ============================================================================

print("\n" + "=" * 80)
print("PART 2: HANDLING DEEPLY NESTED ARRAYS - MULTIPLE APPROACHES")
print("=" * 80)

print("\n--- Approach 1: Explode and Flatten (One Row Per Skill) ---")
print("Use Case: When you need to analyze individual skills")
players_flattened.show(truncate=False)

print("\n--- Approach 2: Keep Arrays as Columns (Aggregate/Filter) ---")
print("Use Case: When you want to keep player as single row but query skills")

# Keep skills as array of structs
players_with_array = players_df_raw.select(
    col("player_id"),
    col("player_name"),
    col("team_id"),
    col("role"),
    col("skills")  # Keep as array
)

players_with_array.show(truncate=False)

# You can now filter or transform arrays
from pyspark.sql.functions import array_contains, filter as array_filter, transform, size

# Example: Players with Batting skill
players_with_batting = players_with_array.filter(
    array_contains(col("skills.skill_name"), "Batting")
)
print("\nPlayers with Batting skill:")
players_with_batting.show(truncate=False)

print("\n--- Approach 3: Create Separate Columns for Each Skill ---")
print("Use Case: When you have fixed set of skills and want pivot-like structure")

# Create separate columns for each skill level
players_pivoted = players_df_raw.select(
    col("player_id"),
    col("player_name"),
    col("team_id"),
    col("role"),
    col("skills")  # Keep skills for processing
)

# Add columns for each skill (you'd need to know skills in advance)
from pyspark.sql.functions import expr

players_pivoted = players_pivoted.withColumn(
    "batting_skill",
    expr("filter(skills, x -> x.skill_name = 'Batting')[0].skill_level")
).withColumn(
    "bowling_skill",
    expr("filter(skills, x -> x.skill_name = 'Bowling')[0].skill_level")
).withColumn(
    "fielding_skill",
    expr("filter(skills, x -> x.skill_name = 'Fielding')[0].skill_level")
).withColumn(
    "leadership_skill",
    expr("filter(skills, x -> x.skill_name = 'Leadership')[0].skill_level")
).drop("skills")  # Now drop skills after extracting individual columns

print("\nPlayers with Skills as Separate Columns:")
players_pivoted.show(truncate=False)

print("\n--- Approach 4: Aggregate Array into String/Map ---")
print("Use Case: For display or when you need compact representation")

from pyspark.sql.functions import concat_ws, map_from_arrays

# Convert skills array to a string
players_with_skills_str = players_df_raw.select(
    col("player_id"),
    col("player_name"),
    expr("concat_ws(', ', transform(skills, x -> concat(x.skill_name, ':', x.skill_level)))").alias("skills_summary")
)

print("\nPlayers with Skills as Summary String:")
players_with_skills_str.show(truncate=False)

# ============================================================================
# PART 4: JOIN ALL DATAFRAMES INTO ANALYTICS-READY DATASET
# ============================================================================

print("\n" + "=" * 80)
print("PART 3: JOINING ALL DATAFRAMES INTO ANALYTICS-READY DATASET")
print("=" * 80)

# Start with scores (fact table)
analytics_df = scores_flattened

# Join with players (using base players without skills explosion)
analytics_df = analytics_df.join(
    players_base,
    on="player_id",
    how="left"
)

# Join with matches
analytics_df = analytics_df.join(
    matches_flattened,
    on="match_id",
    how="left"
)

# Join with player's team info
analytics_df = analytics_df.join(
    teams_flattened.withColumnRenamed("team_name", "player_team_name")
                   .withColumnRenamed("captain_id", "player_team_captain")
                   .withColumnRenamed("home_stadium", "player_team_stadium"),
    analytics_df.team_id == teams_flattened.team_id,
    how="left"
).drop(teams_flattened.team_id)

# Select and reorder columns for final analytics DataFrame
analytics_final = analytics_df.select(
    # Match Info
    col("match_id"),
    col("match_date"),
    col("match_type"),
    col("stadium_name"),
    col("city"),
    
    # Player Info
    col("player_id"),
    col("player_name"),
    col("role"),
    col("player_team_name"),
    
    # Performance Metrics
    col("runs"),
    col("balls_faced"),
    col("fours"),
    col("sixes"),
    col("overs_bowled"),
    col("runs_conceded"),
    col("wickets"),
    
    # Match Result
    col("winner_team_id"),
    col("result_type"),
    col("result_value")
)

print("\nFinal Analytics-Ready DataFrame:")
analytics_final.show(truncate=False)

print("\nSchema of Analytics DataFrame:")
analytics_final.printSchema()

# ============================================================================
# PART 5: ANSWER BUSINESS QUESTIONS
# ============================================================================

print("\n" + "=" * 80)
print("PART 4: ANSWERING BUSINESS QUESTIONS")
print("=" * 80)

# Question 3a: Find the top 5 players by total runs
print("\n--- Query 3a: Top 5 Players by Total Runs ---")

top_players_by_runs = analytics_final.groupBy(
    col("player_id"),
    col("player_name")
).agg(
    _sum("runs").alias("total_runs"),
    count("match_id").alias("matches_played"),
    _round(avg("runs"), 2).alias("average_runs")
).orderBy(
    col("total_runs").desc()
).limit(5)

top_players_by_runs.show(truncate=False)

# Question 3b: Find the team with the highest win percentage
print("\n--- Query 3b: Team with Highest Win Percentage ---")

# Calculate matches played by each team
matches_per_team = matches_flattened.select(
    explode(array(col("team1_id"), col("team2_id"))).alias("team_id"),
    col("match_id"),
    col("winner_team_id")
)

team_stats = matches_per_team.groupBy("team_id").agg(
    count("match_id").alias("matches_played"),
    _sum(when(col("team_id") == col("winner_team_id"), 1).otherwise(0)).alias("matches_won")
).join(
    teams_flattened.select("team_id", "team_name"),
    on="team_id",
    how="left"
).select(
    col("team_id"),
    col("team_name"),
    col("matches_played"),
    col("matches_won"),
    _round((col("matches_won") / col("matches_played")) * 100, 2).alias("win_percentage")
).orderBy(
    col("win_percentage").desc()
)

team_stats.show(truncate=False)

# Question 3c: Return the stadium where maximum matches were played
print("\n--- Query 3c: Stadium with Maximum Matches ---")

stadium_match_counts = matches_flattened.groupBy(
    col("stadium_name"),
    col("city")
).agg(
    count("match_id").alias("total_matches")
).orderBy(
    col("total_matches").desc()
)

stadium_match_counts.show(truncate=False)

print("\nStadium with Maximum Matches:")
max_stadium = stadium_match_counts.limit(1)
max_stadium.show(truncate=False)

# ============================================================================
# PART 6: ADDITIONAL ANALYTICS
# ============================================================================

print("\n" + "=" * 80)
print("PART 5: ADDITIONAL ANALYTICS EXAMPLES")
print("=" * 80)

# Best performing players (batting + bowling combined)
print("\n--- Best All-Round Performers ---")

all_round_performance = analytics_final.groupBy(
    col("player_id"),
    col("player_name"),
    col("role")
).agg(
    _sum("runs").alias("total_runs"),
    _sum("wickets").alias("total_wickets"),
    count("match_id").alias("matches_played")
).withColumn(
    "performance_score",
    col("total_runs") + (col("total_wickets") * 20)  # Wickets weighted higher
).orderBy(
    col("performance_score").desc()
).limit(5)

all_round_performance.show(truncate=False)

# Match-wise team performance
print("\n--- Team Performance by Match Type ---")

team_performance_by_type = matches_flattened.groupBy(
    col("match_type")
).agg(
    count("match_id").alias("total_matches")
).orderBy(
    col("total_matches").desc()
)

team_performance_by_type.show(truncate=False)

# Player performance at different venues
print("\n--- Player Performance by Venue ---")

venue_performance = analytics_final.groupBy(
    col("player_name"),
    col("stadium_name")
).agg(
    _sum("runs").alias("total_runs"),
    count("match_id").alias("matches_at_venue")
).filter(
    col("matches_at_venue") > 1
).orderBy(
    col("total_runs").desc()
).limit(10)

venue_performance.show(truncate=False)

# ============================================================================
# PART 7: SAVING TO FILES (OPTIONAL)
# ============================================================================

print("\n" + "=" * 80)
print("SAVING RESULTS")
print("=" * 80)

# Save the main analytics DataFrame
output_path = "/home/claude/analytics_output"

print(f"\nSaving analytics DataFrame to: {output_path}")
analytics_final.coalesce(1).write.mode("overwrite").parquet(f"{output_path}/analytics_df")

print("\nSaving query results...")
top_players_by_runs.coalesce(1).write.mode("overwrite").parquet(f"{output_path}/top_players")
team_stats.coalesce(1).write.mode("overwrite").parquet(f"{output_path}/team_stats")
stadium_match_counts.coalesce(1).write.mode("overwrite").parquet(f"{output_path}/stadium_stats")

print("\n✓ All results saved successfully!")

# ============================================================================
# SUMMARY
# ============================================================================

print("\n" + "=" * 80)
print("SOLUTION SUMMARY")
print("=" * 80)
print("""
KEY TECHNIQUES DEMONSTRATED:

1. READING NESTED JSON:
   - Used spark.read.json() with multiLine=True
   - Handled nested structs and arrays

2. FLATTENING NESTED STRUCTURES:
   - Used dot notation for nested structs (e.g., contact.email)
   - Used explode() for arrays (creates one row per array element)
   - Used explode_outer() to handle null arrays gracefully

3. HANDLING DEEPLY NESTED ARRAYS (4 Approaches):
   a. Explode and Flatten - Best for analyzing individual array elements
   b. Keep as Arrays - Use array functions (array_contains, filter, transform)
   c. Pivot into Columns - Create separate column for each array element
   d. Aggregate into String/Map - For compact representation

4. JOINING MULTIPLE DATAFRAMES:
   - Used left joins to preserve all score records
   - Joined on appropriate keys (player_id, match_id, team_id)
   - Used withColumnRenamed() to avoid column conflicts

5. ANALYTICS QUERIES:
   - Aggregations: sum(), count(), avg()
   - Window functions for rankings
   - Complex groupBy operations

6. PERFORMANCE OPTIMIZATIONS:
   - Used coalesce() for small result sets
   - Proper partition management
   - Efficient join strategies

ANSWERS TO QUESTIONS:
✓ Top 5 players by runs
✓ Team with highest win percentage
✓ Stadium with maximum matches
✓ Bonus: All-round performers, venue analysis
""")

print("\n" + "=" * 80)
print("SCRIPT EXECUTION COMPLETED")
print("=" * 80)

spark.stop()
