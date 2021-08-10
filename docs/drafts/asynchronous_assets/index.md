# Loading Fonts and Icons Asynchronously


## The Difference Between Synchronous and Asynchronous Loading

After you type in the URL to a website, some administrative magic happens behind the scenes. Here is a sketch of my entire website build, with the browser's request and download happening on the left side of the image:

{{< figure src="trmccormick.com.jpg" >}}

When you load a website, you can use [Chrome's DevTools](https://developer.chrome.com/docs/devtools/overview/) to view how your browser is downloading, organizing, and delivering content from a website to your browser. Here is a quick snippet of the Network tab, with my cache disabled to show what a full request looks like:

![](/page/images/chrome_network_1.PNG#align-center)

As you can see from the Waterfall on the right side of the image, the types of data are being downloaded in the following order: document, script, sytlesheet, font. The 200 status lets your browser know that the file has been downloaded successfully, and the Initiator column lets you know from where that file originated. There are some other helpful columns, such as size of the file, and how many milliseconds it takes for your browser to download and render that data.

Once your browser starts a connection with the web server that hosts a website, it first tries to download the index.html file, which basically is a set of instructions telling it how to render the page you're asking for. In my site, for example, it has some Javascript files that are hosted in some folder on the webserver, and it has some CSS stylesheets that are hosted in another folder. Once you have downloaded everything from my webserver, then it fetches some other files that are hosted on other webservers. In this instance, the only thing that my site is asking you to load are font files, hosted in two different locations: fonts.googleapis.com, and font awesome's CDN. You can see that at this point, the fonts are not loading asynchronously; they start downloading after the files from my webserver are already downloaded.

## How to host fonts locally instead of through a CDN or an API

In order to asynchronously load our fonts, let's work with Google fonts first. We need to go download the woff files from Google, then put it somewhere on our site locally. [Here is an amazing resource](https://google-webfonts-helper.herokuapp.com/fonts/open-sans?subsets=latin) that will help you generate the correct CSS code to host your fonts locally, and package up the right files for your webserver.

If you're hosting a Hugo blog, here is the process I went through:

1. Download the correct fonts from the above link. Package them up in a directory called *fonts*. I put mine in the *public/styles* directory.
2. Create a new section in *public/dist/site.css* and add the CSS snippet from the above link.
3. If you were to reload your site at this point in localhost, you would see the following change, indicating that the Google fonts are now being hosted locally, so they start loading earlier. However, the site still has some code that is telling the browser to also go download the fonts from the Google fonts server.
![](/page/images/chrome_network_2.PNG#align-center)
4. To take out the last call to Google Fonts, you need to delete the <link> reference to the Google fonts in your *footer.html* file. Once you do that, you'll see those calls go away, and your page speed increase:
![](/page/images/chrome_network_3.PNG#align-center)

So in completing these four steps, we've done two things: we've minimized the user's browser's workload, and we've improved the user experience by delivering content to their screen faster (in these screenshots, it looks like it improved it by quite a bit, but we'll check with [Google Page Insights](https://developers.google.com/speed/pagespeed/insights/) to make sure.)

The last thing we are going to do is just repeat the process for the font-awesome fonts. They have a [great tutorial](https://fontawesome.com/v5.15/how-to-use/on-the-web/setup/hosting-font-awesome-yourself) on how to host their icons locally.

This was kind of a pain, taking about an hour to sort things out. But here is a quick overview of what I did different for font-awesome:

1. In my *config.yaml* file, I added a section under params, so it looks like:
    ```yaml
    params:
        custom_css: ["font-awesome/font-awesome.css"]
        custom_js: ["font-awesome/font-awesome.js"]
    ```
   In my static folder, I added a new folder called *font-awesome*, and I placed 3 things in it from the above font-awesome link:
    1. *all.css* (renamed to *font-awesome.css*)
        Within this file, I edited the links to the actual SVG files so that they would match where I put them in the static directory
    2. *brands.js* (renamed to *font-awesome.js*)
        I think at this time I only use font-awesome for the brands that are free. At some point I'd like to pay for the Pro version, but $99/year is too steep for icon hoarding 🙂
    3. the webfonts directory (this contains all of the SVG paths that draw the icons)

2. In the *extra-in-head.html* partial, I added the following code, which lets Hugo know how to use the new site parameters I just declared.
    ```html
    {{ range .Site.Params.custom_css -}}
    <link rel="stylesheet" href="{{ . | absURL }}">
    {{- end }}

    {{ range .Site.Params.custom_js -}}
        <script defer src="{{ . | absURL }}"></script>
    {{- end }}
    ```
3. Finally, I had to take a look at the *font-awesome.css* file and figure out that the CSS class for my brand icons was **fab** instead of **fa**, so I had to go into my *header.html* file to edit the classes.

## What speed improvements you should see

Now, my site loads much faster for users because it is not wasting time going to other webservers. Here is the final screenshot of my Chrome network tab when I load it locally:

![](/page/images/chrome_network_4.PNG#align-center)

And here is the result in Google Page Speed Insights:

![](/page/images/page_speed_async_fonts_solution.png#align-center)
