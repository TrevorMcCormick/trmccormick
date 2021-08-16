# Preparing for the AWS Certified Solutions Architect Associate Exam


The AWS Certified Solutions Architect Associate Exam tests your ability to translate specific client needs into basic cloud architectural designs. While the AWS Cerified Cloud Practitioner Exam covers the core concepts of AWS at a broad level, the Solutions Architect Associate Exam goes a level deeper in all areas. You should have hands-on experience designing end-to-end solutions, deploying VPCs that support various networking, compute, storage, and database strategies.

## Background

There is no better preparation than hands-on experience with AWS. Before I attempted this certification exam, I had about three years of experience working across AWS, primarily using services to build my website and handle data ingestion and warehousing processes at work. I had drawn out some simple architecture documents up to this point, and I could generally describe what was happening. However, I knew that in order to pass the exam, I would need to strengthen my understanding of services I was already familiar with (S3, RDS, IAM), and spend a significant amount of time learning the ones I did not use day to day (VPC, Route53, Networking, etc). 

Here is a link to [the exam guide](https://d1.awsstatic.com/training-and-certification/docs-sa-assoc/AWS-Certified-Solutions-Architect-Associate_Exam-Guide.pdf) which identifies the four content domains you must know in order to pass: resiliency, high-performance, security, and cost-optimization. When you study for this exam, if you're reading about a specific service, or building something out in the console, try to understand the service offering with these four concepts in mind. Some key questions to ask yourself might be: what happens if this service fails? how can I scale my application to meet demand? how can I lockdown the components of my VPC so that it is protected from internal and external threats? is this the most cost-effective way to achieve my goals?

## A Cloud Guru

I felt like the first best step for me would be to get through all of the videos and exercises in [A Cloud Guru's - AWS Certified Solutions Architect Associate SAA-C02 course](https://acloud.guru/overview/aws-certified-solutions-architect-associate). There was 45 hours of content in this course alone, so it was definitely a big first step.  

As I was going through this course, I browsed through some of the other offerings, and found the [AWS Well-Architected Framework course]](https://acloud.guru/overview/aws-well-architected-framework) fairly helpful. 

What I found MOST helpful was the hands-on labs. Here is a curated list of labs I found most helpful:

* [ALBs and Auto-Scaling](https://learn.acloud.guru/handson/feb3bc2b-c912-4f5c-94d7-bfbedea6319f)
* [AMIs](https://learn.acloud.guru/handson/a95ff0ea-4d92-4c80-ad92-35f42389b4a4) 
* [Bastion Hosts](https://learn.acloud.guru/handson/82ac8bc4-ccd3-4f28-8a96-124923392764)
* [Database Migration](https://learn.acloud.guru/handson/761e1ac8-8825-4772-af95-4ba878883e9d)
* [EBS Volumes](https://learn.acloud.guru/handson/f234c76a-c804-4d89-81ca-524514cdc59d)
* [RDS](https://learn.acloud.guru/handson/aacf9e92-0bb7-4969-aaf7-e2e106a7e339)
* [SQS](https://learn.acloud.guru/handson/0861366a-855b-4ff0-a6f6-ac93e2738dbd)
* [VPCs](https://learn.acloud.guru/search?page=1&learningTypes%5B0%5D=ACG_HANDS_ON_LAB&labModes%5B0%5D=GUIDED&technologies%5B0%5D=VPC&cloudProviders%5B0%5D=AWS)


## FAQs, Cheat Sheets, and Tutorials

After taking the two ACG courses and moving through these labs, I used the following resources to prepare for the ACG practice exams:
* [AWS Cheat Sheets by Tutorials Dojo](https://tutorialsdojo.com/aws-cheat-sheets/)
* [AWS FAQs](https://aws.amazon.com/faqs/)
* [AWS 200-level Hands-On Tutorials](https://aws.amazon.com/getting-started/hands-on/?nc2=h_ql_le_gs_t&getting-started-all.sort-by=item.additionalFields.sortOrder&getting-started-all.sort-order=asc&awsf.getting-started-category=*all&awsf.getting-started-level=level%23200&awsf.getting-started-content-type=*all)
* [AWS Reference Architecture Diagrams](https://aws.amazon.com/whitepapers/?e=gs&p=gsrc&whitepapers-main.sort-by=item.additionalFields.sortDate&whitepapers-main.sort-order=desc&awsf.whitepapers-content-type=content-type%23reference-arch-diagram&awsf.whitepapers-tech-category=*all&awsf.whitepapers-industries=*all&awsf.whitepapers-business-category=*all&awsf.whitepapers-global-methodology=*all)

After all of this preparation, my wife basically told me I needed to stop studying and just take the exam 😅 So that's what I did!

## Celebrate

You should have a great cloud foundation if you dove into the above resources and put in the work. You can comfortably build a VPC from scratch, you can start tinkering with your own cloud solutions, and you should be able to understand and contribute to your team's cloud strategy, even if your team uses another cloud provider.

Although I do not think will proceed studying for the Solutions Architect Professional exam, I do want to improve my ability to set up cloud solutions for clients. I'm planning to learn more about tools like CloudFormation, Elastic Beanstalk, and all of the analytics services. I'm currently on the learning path through ACG to take the Data and Analytics specialty exam in the next couple of years.

{{< figure src="/aws_cssa.webp" width="80%" >}}
