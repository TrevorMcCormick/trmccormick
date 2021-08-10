# How To Query PostgreSQL in AWS RDS with Python


In this post I'll walk through:
* how to create a public PostgreSQL instance in RDS using free-tier
* how to create a table and load it with data from a csv file
* how to query data from that table using psycopg2

## PostgreSQL on RDS
The only thing you have to do in the AWS console is create a Postgres DB instance and make sure it is open to the public (just for this example). Here is how to do that:

* Go to [Databases in RDS](https://us-east-2.console.aws.amazon.com/rds/home?region=us-east-2#databases:), and choose the region you want to create a database instance
* Create a database, selecting "Standard Create", and the PostgreSQL configuration. Make sure to use free-tier. 
* You can name the database anything you want, and choose a username and password. 
* The most important step is in "Connectivity": make sure to fill in the bubble for "Yes" to Public Access. If you're using this database for any real-life work, then you'll want to fill in "No". You'll have to do some work to configure security groups and look at your architecture to only allow connections you want to approve if that is the case.
* Once the database has been created, you'll be able to find the database endpoint in the "Connectivity & security" section. You'll use that to create a json file with your credentials, which should look something like this:

    ```json
    {
    "user":"postgres",
    "password":"password",
    "database":"postgres",
    "host":"xxxx.xxxxxxx.us-east-2.rds.amazonaws.com"
    }
    ```

## Query with Python
So you've set up a Postgres DB instance, but there is no data in it. We'll need to connect to the instance and load data with Python. To go forward with this exercise, you'll need **pip**, and you'll need to install the follwing packages: `psycopg2-binary`, `pandas`, and `sqlalchemy`.

I've provided some example functions that you can use to get started. Here is a quick summary of the sections, with the actual python code at the bottom of the post.

* **Import**: so you can skip a bunch of database driver steps
* **Client**: to connect to the psql instance for queries
* **Load**: to load data into psql. I only put one function in this class for an example, so you can create and load a table in one step.
* **Query**: to query data in a table within your DB instance
* **Meta**: to inspect the DB instance

## Google Colab

Most of my ad-hoc work is done in [Google Colab](https://colab.research.google.com/) because it's easy to run code blocks and debug interactively. I'm going to share an example Colab Notebook with you so you should be up and running fast. [Here is the link to the Python Notebook](https://colab.research.google.com/drive/1HmU9yFTJ30LzLf9ql8ahCcIuSb8RDh89?usp=sharing) that you can upload to your own Colab environment.

In the Google Colab environment, you need to upload two files: your credentials json file, and your dataset. In this case, I've downloaded [the iris dataset](https://gist.githubusercontent.com/curran/a08a1080b88344b0c8a7/raw/0e7a9b0a5d22642a06d3d5b9bcbad9890c8ee534/iris.csv) and I will upload it to my DB instance as the table **iris**.

### Video Walkthrough

Below is a screen recording of me going through the Colab process. I'm uploading two files, and running through all the code blocks to connect to my DB instance and work with it. 

{{< youtube cJdXgguTEeY>}}

And here is the Python code you can copy and try out for yourself:

{{< gist TrevorMcCormick 2ecd84cb974ed0370833aff84546ce92 >}}
