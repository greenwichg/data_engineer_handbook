# SQL Interviews in Data Engineering: A Complete Guide

SQL and data engineering are like peanut butter and jelly. In every single data engineering role I've ever had, I've been asked SQL questions for at least an hour. This is a round that I personally feel very confident in since I have never failed it. In this newsletter, I'll be covering the key details that you'll need to know to pass these common interviews.

## What are the types of SQL interviews in big tech companies

Big tech companies like to ask a lot of questions from their engineers. There are usually two types of interviews for SQL.

### The screener interview

This interview is 45-60 minutes. The questions here are usually pretty easy compared to the onsite round. The goal here is to show that yes, you can code in SQL. Answering the questions is usually enough to pass the round.

### The onsite SQL interview

This interview is 60 minutes. The questions here go more in-depth. You'll be asked a lot about table scans and optimizations. It's unlikely your first solution will be the most optimal one.

```sql
SELECT success FROM interviews
WHERE optimizations = TRUE
AND windows_functions = TRUE
AND ansi_sql = SOMETIMES;
```

---

## The screener interview in detail

In the screener interview, they usually ask four to five questions:

### 1. A simple question that requires a WHERE condition with a GROUP BY

This question is mostly to build your confidence and to give everyone who interviews a small win even if they don't pass.

### 2. A question that requires you to do a JOIN + aggregation

Make sure to be able to talk about the differences between LEFT, RIGHT, INNER, and FULL OUTER JOIN. If you don't know the differences, you won't pass.

### 3. A question that requires you to do a window function

The most common question here is the "second highest salary" question. The use of RANK, DENSE_RANK, and ROW_NUMBER functions is very common here. Know the differences between these functions and also how to use PARTITION BY in window functions.

### 4. A question that requires you to use a common table expression or subquery plus a technique from one of the questions above

- Using the WITH keyword and creating a common table expression is usually better than using a subquery for this problem. It'll help you maintain readability while also making it easier to keep your thought process clear
- Use good alias names here so that in the subsequent queries you can filter or aggregate easily

### 5. A question that requires a self-join or one that starts to dig deep into optimizations

A self-join is one way to solve a problem. Usually, another way to solve the same problem is usually LAG/LEAD window functions. Some places like, Facebook/Meta want you to use only ANSI SQL so knowing that you can replicate LAG/LEAD window functions with a self-join. This is kind of annoying since LAG/LEAD are pretty standard and more performant!

**If you can solve four or five of these SQL questions in 45 minutes, you'll pass and be able to go to the onsite round of the interview.**

---

## Most common mistakes in screener interview

I've given over a hundred of these screener interviews in my time in big tech and here are the most common mistakes I see.

### Jumping right into coding before clearly understanding the problem

This mistake is critical because it wastes the valuable 45 minutes that you have. Spending 1-2 minutes asking questions to save yourself 5-10 minutes debugging is critical for success in these interviews. It also illustrates to the interviewer that you have good communication skills!

### Relying too heavily on UDFs or engine-specific code

Most of the interviews are going to be using basic MySQL or Postgres. If you need a fancy SparkSQL UDF to solve your problem, you're going to fail.

### Relying too heavily on window functions

Not knowing how to replicate window functions with self-joins and pure ANSI SQL is a common mistake I see engineers make.

### Not communicating with the interviewer

The interviewer will give you hints and guidance. Trying to solve the problems through sheer coding will is not the right approach and I've seen many people fail this way.

---

## The onsite SQL interview in detail

This interview is one of the last interviews that stands in the way of you getting that shiny big tech offer! You can think of it as the last SQL boss. This interview is considerably different from the screener interview. You'll usually be asked fewer questions but in much more detail.

You'll be given a set of data tables and how they relate. The questions that you'll be asked are various so I'll give you some keyword mappings to help solve them:

### If you hear ordinal words in the question (i.e. first, second, third, etc)

This is a signal you should be using a window function. This usually means you'll solve the problem with DENSE_RANK or ROW_NUMBER. Having a firm understanding of how ties work between these window functions is important.

### If you need to count multiple things with a condition

It's much better to do:

```sql
SELECT 
    COUNT(CASE WHEN condition = 'value' THEN 1 END), 
    COUNT(CASE WHEN condition2 = 'value2' THEN 1 END) 
FROM table
```

vs

```sql
SELECT COUNT(1) FROM table WHERE condition = 'value' 
UNION ALL 
SELECT COUNT(1) FROM table WHERE condition2 = 'value2'
```

**The reason for this is table scans and performance.** You need to be able to solve the problems with the fewest number of table scans possible.

### If you hear the word "rolling" or "cumulative"

You should think window function again. For example, here's a 30 days rolling sum:

```sql
SUM(value) OVER (ORDER BY date ROWS BETWEEN 30 PRECEDING AND CURRENT ROW)
```

### If you might hear something like, "likes by country" or "metric by dimension"

This should be a signal to either use GROUP BY or PARTITION BY + window function depending on if it's coupled with an ordinal term or a "rolling/cumulative" term.

### Find all the things that don't have X attributes

For example, "find all the Facebook users who have no friends"

This should signal to use LEFT JOIN + WHERE IS NULL:

```sql
SELECT * 
FROM users u 
LEFT JOIN friends f ON u.user_id = f.user_id 
WHERE f.user_id IS NULL
```

### Additional expectations

Remember that speed in answering questions here is important but so is the detail and expertise that you express. Be prepared to also answer follow-up questions about:

**Query plans and table scans**
- I used the EXPLAIN keyword during my interview with Airbnb and actually stepped through the plan with them. I did get the job.

**Optimizations, index usage, and partitioning**
- Can you talk about the read-write trade-offs of index creations?
- What would happen if we partitioned the table by date or some other low-cardinality column?

---

## Interview tactics that I used to also help

Remember that technical interviews are interviews and not tests!

**Make the interviewer laugh**  
I make it a goal of mine to try and make the interviewer laugh. Being personable and treating the interviewer as a person and not a test-giver can do wonders. Especially if you're on the edge between passing and failing the interview. Being likable can help bias the interviewer's rating of you into landing the job.

**Give your brain a little bit of time to reset and refresh**  
Sometimes big tech wants you to do four to six hours of interviews in one block. I ask for at least 30 minutes between each interview so I can reset my brain and research about the next interviewer so I can look more prepared and ask better questions. These types of accommodation are rarely asked for but almost always given! You'd be surprised how asking something vaguely personal like, "How have you liked working at Netflix for the last 7 years?" gets the interviewer to think you're cooler than you might actually be.

**For my readers with ADHD and anxiety**  
I highly recommend getting some exercise in before the interview to reduce the jitters. I always do a short 10-15 minute run before these interviews and that helps a lot!

---

## Closing thoughts

What other things do you think are needed to pass these interviews? They're tough but if you focus on the right words and translating them into SQL, you can definitely pass these rounds!

If you liked this content, please share it with your friends and comment on what other type of data engineering interview content you'd like to see!

I cover all types of interview content in my data engineering course on DataEngineer.io!, including data modeling, SQL, data architecture, behavioral and data structures, and algorithms interviews!