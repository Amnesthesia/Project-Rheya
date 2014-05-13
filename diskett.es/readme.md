# diskett.es

## Abstract
diskett.es is a front-end for the already existing application **EpisodeGuide**, which helps users stay up to date on their favorite TV shows. All users can browse TV shows and read more about them and the episodes in each season.

A significant difference between the base application **EpisodeGuide** and **diskett.es**, is that diskett.es is a *real web application* and not just a web site. By web application, we mean that it's a lot more similar to a native application than sites normally are.

Features are very similar to EpisodeGuide's features, however, everything happens client-side without reloading the page. Something we stated in the first project report, and which we will iterate again, was that what separates our application from others, is its simplicity and ease of use -- it doesn't get more intuitive!

Users are able to ...

* ... sign up in just a few seconds
* ... log in
* ... find (and follow) new (or old) shows
* ... keep the shows they like in a Following list

## Overview

### Introduction
diskett.es uses the popular jQuery based framework **EmberJS** at its base, which is a fully client side javascript Model-Viewer-Whatever framework.

This means that we get some additional initial loading time for the site, but after everything has loaded, each page load happens *instantaneously*. This gives the user a very slick experience similar to a native application -- think about it, what ***IS*** an application? 

An application is usually downloaded code that is then run on a users machine. The code then present the user with a user interface, and allows the user to perform various actions. The difference here being that the code is downloaded and executed in the sandboxed environment of a web browser. This is why it's commonly referred to as a *web application* and not just a web site.

### Functionality
The functionality listed above pretty much sums it up, but can be described more in-depth as follows:

* Index - Redirect to Show list
  * Show list
    * Individual show
      * Subtitles for an episode
      * Torrents for an episode
  * Login section
    * Shows followed by the user
      * Individual show (see above)
    * Calendar view of upcoming episodes
  * Help
* Navigation

This is how we want the sub-pages to be organized from the index page. First, users should be presented with a list of all shows. They should then be able to click any individual show to get to a page containing the information about that show.

For all other sub pages, users should be redirected to the login page first. After signing up and logging in, users should be able to access a page that lists all shows they are currently watching; a calendar that shows all upcoming episodes of the shows the user is currently watching, as well as functionality to Follow a show on any page where a show is displayed.

When viewing an individual show, there should be a list of episodes for that particular show, and clicking on an episode should bring up a list of subtitles and torrents for that specific episode.

### User Interface

#### UX
The user interface should be responsive, as a lot of users access the internet from portable devices such as phones, tablets or phablets. Therefore, it's necessary that the page adapts according to screen-size, and for this reason we have chosen to use Twitter Bootstrap as the base for styling.

The user experience is where we can beat competitors, and that's why we want to provide an ad-free, slick user interface that runs smoothly on any device. The page should not require reloading, and all user interactions that require communication with the database should be done with AJAX requests to an API.

Furthermore, animations should make the site appear more like an application, and less like a conventional web page.

#### UI
The most important part of any site is the navigation. For navigation to be the most apparent element on the site, and work equally well on mobile devices, the site should be split in two:

1. A sidebar to the left containing the menu in the form of large icons
2. Page content to the right displaying the content the user has requested

For additional interaction on a page, modal boxes should be used to avoid switching to another page unless it's necessary.


### An in-depth look

Because Ember is a Model-View-Controller framework, this means that we have a set of **Routes**, **Models**, **Controllers**, **Views**, and **Templates** which make up the site (in addition to *components*, *helpers* and *mixins*).

Like with most MVC frameworks, we have *Routes* that control what context the user is viewing and thus, as the name implies, what *route* the user is currently at. In Ember, Routes are usually visible to the user in the form of URLs, which can be seen as /#/route. Routes are assigned resources, which control what model and controller will be used for the route, and that's where the magic happens. We'll go more into detail of what each of these system components do further on.

Ember builds on jQuery, and as such, we can access jQuery from the (only) global object `Ember`, at `Ember.$`. Even though Ember is completely build on top of jQuery, it still make use of a few other javascript libraries, albeit not to the same extent. These other libraries are:

* RequireJS 

    RequireJS is used for including the right files at the right time.
* NodeJS 

    This is not required, but we use it to write classes as individual NodeJS modules. Classes could also be exported as RequireJS modules.
* HandlebarsJS 

    Handlebars is a very powerful but minimal templating system built on MustacheJS (named so because of its use of 'mustaches', or {{ }} for variables) but adding extra functionality such as conditional statements. This is very vital to Ember and lays the foundation of Ember's powerful data templates.

#### API & Server communication
As we described above, part of the user experience is to ***not having to reload the page***, and perform all user interaction with the database through AJAX requests. To do this, we require some sort of web services. There are of course a bunch of different conventional ways of achieving these, most notably SOAP, REST or XML-RPC. We have gone for a RESTful API, and although not fully implemented, it covers just about enough for what we need. This RESTful API makes use of the DatabaseHandler and the database in **EpisodeGuide** to retrieve and modify data, and we cache this data locally in the web browsers LocalStorage after being retrieved.

By default, Ember makes use of its own Store. The Store is actually a separate component (which is not yet fully production ready, but it is operational) called Ember-data. This store allows data to persist in the browsers LocalStorage even on page refresh, which helps us remember things (like user sessions for example) we need, and reduces the amount of required API queries.

The data to fill up the Store is commonly retrieved from an HTTP server providing a RESTful JSON API. Unfortunately for us, Ember seems to have been greatly unfluenced by Ruby on Rails, which provides an API out of the box. PHP, being a language and not a framework, does not provide this. Therefore, to be able to work with Ember's data request, we have taken the effort of writing our own RESTful API to create and update data in the database. Although Ember is highly customizable, the easiest way of doing this is simulating such an API, which is what we have done. By following the URL conventions Ember expects, working with data from our database becomes rather smooth. These URL conventions, using "Show" as an example, are as follows:

| Action   | HTTP State    | URL      | Description                                  |
| :------: | :-----------: | :---:    | -------------                                |
| Find     | GET           | /shows/1 | Fetches an individual show from the database |
| Find All | GET           | /shows   | Fetches **all** shows from the database      |
| Update   | PUT           | /shows/1 | Updates an individual show in the database   |
| Create   | POST          | /shows   | Creates new shows in the database            |
| Delete   | DELETE        | /shows/1 | Deletes a show from the database             |

For retrieving data, the expected output is a JSON object. Because a **Model** can have *relationships* with other models (a Show, for example, hasMany('Episode')), it is expected to return the IDs for its children as well, with the children provided afterwards. An example of this is:

```json
{
"shows":
 [{ "id":104641,
    "imdb_id":"tt1255913",
    "zap2_id":"SH01173055",
    "channel_id":"HBO",
    "poster":"a18f12207b4aa480314ace7f77310f83.jpg",
    "lang":"en",
    "pilot_date":"2009-09-20",
    "name":"Bored to Death",
    "summary":"Jonathan Ames, a young Brooklyn writer, is feeling lost. He's just gone through a painful break-up, thanks in part to his drinking, can't write his second novel, and carouses too much with his magazin",
    "rating":8.3999996185303,"
    lst_update":"2014-02-14",
    "episodes":
        ["104641,1,1",
         "104641,1,2",
         "104641,1,3"
         ]
 }],
 "episodes":
 [
    {
     "id":"104641,1,1",
     "show_id":104641,
     "season":1,
     "episode":1,
     "summary":
     "Broken up after his breakup with his girlfriend Suzanne, Jonathan Ames reads through Farewell My Lovely, his favorite book by Raymond Chandler. Enlivened by the novel, Ames places an online advertisement as an unlicensed private investigator. His fir",
     "date":"2009-09-20"
     },
    {
     "id":"104641,1,2",
     "show_id":104641,
     "season":1,
     "episode":2,
     "summary":"As Jonathan tries to mend his relationship with Suzanne, another case falls onto his lap. This time, he is tasked by a woman named Jennifer to gather proof of her boyfriend Gary's infidelity. Jonathan, who learns his new client loves to drink as much",
     "date":"2009-09-27"
    },
    {
     "id":
     "104641,1,3",
     "show_id":104641,
     "season":1,
     "episode":3,
     "summary":"While attending a New York film society function, George introduces Jonathan to a filmmaker, who asks him to rewrite a screenplay. Later, he goes out with a party girl and leaves the script at her home, which happens to be a shrink's office. Jonathan",
     "date":"2009-10-04"
    }
 ]
}
````
For brevity, we showed only 3 episodes in the output example above, but there may be a lot more. A few things to pay attention to here is the ID. As you can see in the example above, the "id" column actually consists of three comma-separated numbers found again right below it: *show_id*, *episode*, and *season*. This is because each Episode is actually identified in the database by these fields as composite keys, and Episodes **do not have** an ID field. However, Ember being inspired by Rails, **requires** objects to be identified with a field **required** to be named "id", and child-objects cannot be identified by composite keys. The workaround we have implemented for this is to let MySQL solve this when it retrieves the episode rows, with a ``CONCAT(`episode`.`show_id`,',',`episode`.`season`,',',`episode`.`episode`)`` query. Requests for episodes can then work out the composite keys from this "virtual id" key.

Another thing you may have noticed in this example, is that the *Show* object has a key called *episodes* in plural. This is because Ember expects hasMany relationships to be represented in plural, telling it that "Hey, this object has an array of ids for multiple child objects you can use for the hasMany relationship of the same name!" and after loading the Show object, it will then look for the Episode objects that follow with these key, and make the association.

After a Show has been loaded, all Episodes for that show can be retrieved from `Show.episodes`. Similarly, when updating objects, a PUT request will be made to the server with the appropriate ID, containing an object like this.

Now that we've briefly explained how the client-server communication works, lets take a look at the role of the different system components and where these can be found.

#### Structure & File Structure

Files are located in the following directories:


Configuration files:
* `/js/config/app.js`
* `/js/config/store.js`
* `/js/config/routes.js`

All individual classes and templates:
* `/js/routes/`
* `/js/models/`
* `/js/controllers/`
* `/js/views/`
* `/js/templates/`


#### Routes
So, what is a Route, exactly? Well, you could think of it as a context. Our application, diskett.es has many contexts it can be shown in. For example, when the user is looking at a list of all shows, that's one context. When the user browses to the shows he or she follows, that's another context. We're still working with the same database, but we're displaying different information depending on the context, and even if we're displaying the same information, like displaying a list of all shows, or a list of shows the user is following, we're displaying it with similar but different contexts. 

So why is it called a Route? That's because it's a web application. The default route would be the base URL of the site, and all *further* paths from there would be considered different routes. `/shows/` would be a different route from `/account/`, for example, and these do different things. A Route sets up the context which we're working in, fetches the information we need to present to the user and passes it on to the controller, and then renders the page.

A route will by default contain the model of the same naming convention as the route -- for example, if the user visits the route *Shows*, the *ShowsController* will be loaded and passed the appropriate model. Because *Shows* is *Show* in plural, and according to naming conventions (which we will mention briefly later on in this document), Ember will assume that this is a collection of *Show*, and as such, it will return an array consisting of all available Show objects.

The main file for Routes is called `routes.js`, and can be found in:

``/js/config/routes.js``

This is the file where all routes are actually **declared**. We can declare routes *without* having to then **define** them, and if we do that, Ember will dynamically create a Route object for that route, as long as it has been declared. However, if we want to *do* something with the route, we have to further define it to add functionality (such as performing actions, retrieving variables, or making sure the route is only accessible when a user is logged in).

To further define a route that has been declared, we set up a Routes object as such (again, we will use retrieving and displaying an individual `Show` as an example):

```javascript
var ShowRoute = Ember.Route.extend({
  model: function(params){
        return this.store.find('show', params.show_id);
  },
  renderTemplate: function(){
    var controller = this.controllerFor('navigation');

    this.render('show');
    this.render('navigation', {
                                outlet: "navigation",
                                controller: controller
                             })
    }
 });

module.exports = ShowRoute;
```

Now, here's a lot of information to take in at once, which makes it a rather good example of what a route actually does. First of all, the Routes map in `routes.js` has detected that we want to view a *Show*, so it has now delegated the rest of the job to the ShowRoute (again, Ember's naming convention says that for a model called **Show**, the route is **ShowRoute**, and the controller is **ShowController** by default).

The ShowRoute extends the default Ember.Route with additional functionality. Remember what we mentioned about Ember dynamically setting up Routes for routes that are declared but not defined in the Routes map? The object it sets up is a regular Ember.Route -- we want to extend the functionality of the default route here, that's what this example is all about!

First, what we do is to set up a *model* for this route. This model can then be retrieved by the *ShowController* when it tries to get the model for the context it's in by calling `this.get('model')`. A very exciting feature of Ember is something called *computed properties*. Essentially what that means is that classes (we know, we know, "javascript does not have classes", but you get the point!) can have properties that are not just values, but functions that *return* a value. This is what's happening in the snippet above! The *model* property of the route here is actually a function that contacts the **Store** to find a *Show* object with the help of a parameter to identify it. If it exists in the store already it will be returned, and if it doesn't, Ember will contact the REST API it has been set up to use (or any other adapter actually, but we use REST in our project) to find it, and then returns a fully set up Ember.Model of that type.

Furthermore, we have a *renderTemplate*. This is the default method Ember calls on a route to render the page and find out what data it should show, and where. By default, the application template only has one area for displaying data, so normally, Ember would just put the *template* into that area. But we want to show several areas in our application: The Sidebar for navigation, and the page content.

That's what the *renderTemplate* method does here. It tells Ember to render *Show* with its associated controller, view and template into the default area, but also to render *Navigation* with its own controller, view and template into another area (or, 'outlet') on the page named 'navigation'.

A line similar to the last one can be found in most files for individual classes. This is because each individual class is exported as a separate **NodeJS module**.

Well, isn't that great? But what about that model that was returned? And what happens with it? 

#### Models

A *model* is a set of data, commonly used to represent a single row in a database table along with its relationships. In Ember, a model is an extension of the base class Ember.Model; extended with additional attributes. Although JavaScript typically does not requir strict datatypes, we can set up attributes as strict types in Ember. That is however not required, and Ember can usually figure out the type anyways, but the types available are: Number, String, Date and Boolean. 

We can then add some relationships to the model, which tells Ember that this model has children (or parents) that should be associated with it. In doing, so, we can get all Episodes that belong to a Show, for example. All data we retrieve from the database through the RESTful API is represented in models -- we'll use the `Show` model as an example here to keep that red line from previous examples:

```javascript
var Show = DS.Model.extend({
    imdb_id: DS.attr('number'),
    zap2_id: DS.attr('number'),
    channel_id: DS.attr('number'),
    poster: DS.attr('string'),
    pilot_date: DS.attr('date'),
    name: DS.attr('string'),
    summary: DS.attr('string'),
    lang: DS.attr('string'),
    rating: DS.attr('number'),
    episodecount: DS.attr('number'),
    lst_update: DS.attr('string'),
    watched: DS.attr('boolean'),
    episodes: DS.hasMany('Episode')

});

module.exports = Show;

```
Ember does not want us to define the property *id*, as this is something it works out itself from the JSON set it retrieves, and uses internally for managing the relationships. **This is the object the JSON example earlier would map onto.**

Now that we know what the data objects we're working with look like, and how the context of the page is figured out, let's see how we can **control** this information and users **actions** -- that's what we do in the **controller**.

#### Controllers & Actions

*Controllers* is what manipulates data according to user actions; for example, if the user clicks something, the controller is responsible for reacting on this and making something happen. In a server-side Model-View-Controller system, this would typically happen when a user clicks a link, and different parameters (such as GET or POST variables) define the action the user wants to take. On the client side, the user would only see a static rendered HTML page, and there would be no client-side MVC logic; everything would happen before the page is loaded. In a client-side MVC web application like diskett.es, it's the other way around! The site is first loaded in its entirety, and what's displayed is only a part of what's loaded in the browser. Clicking a link does not lead to another web page, it simply calls a javascript function in the already loaded page. And there you have it. That is what we call an **action**.

Actions can be located in any of the already described system components (except for models!), as well as in a view. Routes, Controllers, or Views may contain actions. In Ember, actions *bubble*. This means that when the user clicks something in the template that has been declared an action, it will go through these steps to find it:

* Does the action exist in the current **view**?
** If it does, it will be triggered.
* If it does not, continue to check if the action exists in the current **controller**
** If it does, it will be triggered.
* If it does not, continue to check if the action exists in the current **route**
** If it does, it will be triggered.
* If it does not, continue to check if the action exists in the default route, the ApplicationRoute
** If it does, it will be triggered.

This is what's called *bubbling*, a reference to a bubble rising up through water all the way from the bottom. We use these to let users perform actions from templates, such as clicking a link, submitting a form, or otherwise call predefined functions on-demand. In our application, we want to allow users to **follow** shows in different contexts. We could just implement the **follow** method on every controller of every part where a Show might be displayed, but this would result in unnecessary code! Therefore, we can just implement it straight into the ApplicationRoute, allowing the action to bubble up and be captured on any part of the site even without a show object necessarily being visible. However, when a Show object is visible, we override that method in the Show controller, and that stops the action from bubbling up further.

The controller is also where we make the most use of **computed properties** as we mentioned earlier. In Ember, there are three types of Controllers:

* **ArrayController**: This one contains an Array of models (or even an Array of controllers specified as an itemController property)
* **ObjectController**: This type of controller works with only one object (model)
* **Controller**: This controller type works without any model (for example, this one is used for the NavigationController, where we don't work with any models but we still work with user actions)

Because there are three types of controllers, giving an example of each individual one would be excessive. To stick to the same red line as previous examples, we'll show the controller used for an individual show, but with some *computed properties* omitted for brevity, as to only show how it works:

```javascript
var ShowController = Ember.ObjectController.extend({
        ratingText: function(){
            return (this.get('rating').toFixed(1));
        }.property('rating'),

        actions: {
            follow: function(show_id){
                // Get the current user session and check if user is logged in
                if(!this.get('session').isAuthenticated)
                    this.transitionTo('login');
                                              
                // Get the current user from session in the store
                var user = this.store.find('user',this.get('session.account.id'));
                
                // Get the list of shows from the current logged in user's account,
                // then find the show object in the store, and push it to the list.
                this.get('session.account.shows').pushObject(this.store.find('show',show_id));
                
                // To save the user, we must wait for the user object to be fully loaded, then we can save it.
                this.get('session.account').then(function(response){
                                                                    response.save();
                                                });
                // Hide the show from the list (it can still be found under the users list of Followed shows)
                Ember.$("#"+show_id).hide("slideLeft");
            }
        }
});

module.exports = ShowController;
                                                                    

```

As seen here, we have one computed property (ratingText) that operates on the 'rating' property of the default ShowController's model (Show), and returns the rating property with only 1 decimal. When trying to access `show.ratingText` in a template, this method will be called and that value will be returned, just as if it was a regular property value.

We also have the action *follow*, which lets the user add the show to the list of shows he or she follows, by taking the show's ID as a parameter, and then checking if the user is logged in. As we mentioned previously, **actions bubble up the hierarchy**, and this is why clicking links, although it is an action performed by a user, is typically handled by the Route-map. The action of clicking the link is a special type of action that bubbles up all the way to the routes, and the appropriate transition to that page is then carried out. Thus, only *pure* user actions such as interacting with elements in different ways, like when a user follows a show, is handled in the Controller. However, when a user interacts with different elements on the page, for example, clicking a button to hide an element, this is something that should be handled in the **view**. Although it's not required, that is how it should be done by convention -- a view should not perform requests to the database, or working with models, it should only aid in presenting what the user **views**. That being said, we'll take a closer look at views and templates below.

#### Views & Templates

A *view* controls the visual part of the system normally, but with Ember and Handlebars, views may often seem redundant. Handlebars templates are so powerful in displaying data that views may often not even seem needed -- and oftentimes they aren't. As mentioned above, a view is normally only used if the user needs to interact with the elements on the page, such as performing drag-and-drop, hiding or showing elements, or otherwise manipulating the information presented to the user.

For actually presenting the data, we make use of Handlebars templates. These are `.hbs` files and can be found in

`/js/templates/`

These templates are normal HTML files, but compiled into javascript strings when the whole application is minified into one big file. In this way, even the HTML of diskett.es can be contained in the javascript file, but this is not required. It does, however, speed up initial loading time greatly.

Handlebars files, in addition to containing regular HTML, may also contain conditional statements and loops, which is what makes it so powerful. Just like in PHP, where a `foreach` look can be used to output a list of objects encapsulated in identical elements, a Handlebars `{{#each}}` statement can be used to achieve the same result.

For an individual Show object, we don't really use a lot of functionality to manipulate the element. However, we have added an example of a function that could be used if we were using jQuery DataTables.js to format a table in the template of the view:

```javascript
var ShowView = Ember.View.extend({
    templateName: 'show',
    tableize: function(){
        this.$('.table').dataTable();
    }.on('didInsertElement')
});

module.exports = ShowView;
```
The property `templateName` does not have to be set if the name of the template is the same as the name of the view/model being displayed. However, it goes to show that a view can display different templates if requested, by changing this property.

The `tableize` method here only selects all HTML elements in the template with the `table` class using jQuery, and then runs the function `dataTable()` on them. This should be done when the view is done inserting elements on the site, something Ember.View manages, and therefore we use the hook `.on('didInsertElement')`.

This example, although it contains a lot of regular HTML as Handlebars templates do, is located in `/js/templates/show.hbs`. All Handlebars templates can be found in this folder, and are then precompiled before the application is deployed. You'll notice a few different types of syntax surrounded by handlebars, mustaches, or curly brackets if you will, that allow us to perform conditional output as HTML fully client-side.

```html
<!-- Display the show's rating as a progress bar -->
<div class="progress progress-striped browse-item-rating-progress topbar" id="browse-show-rating-progress">
  <div class="progress-bar {{unbound progressType}}" style="width: {{unbound ratingLength}}%">
    <div id="browse-show-rating">{{ratingText}}</div>
  </div>
</div>

<!-- Print the content in the container -->
<div class="container">

    <div class="row">
				<!-- First, display the poster for the show -->
        <div class="col-lg-4">
            <img src="../media/posters/{{unbound poster}}" class="detailsimg"/>
        </div>
				<!-- In the next column, display the other information as text -->
        <div class="col-lg-8 columns">
            <div class="row">
								<!-- First, display the name -->
                <div class="col-lg-8 columns">
                    <h1>{{ name }}</h1>
                </div>
            </div>
						<!-- Add an empty row, for space -->
            <div class="row">
            </div>
						<!-- Display the summary in a paragraph block -->
            <div class="row">
              <div class="col-lg-8 columns">
                	<p>{{summary}}</p>
							</div>
       			</div>
						<!-- Add an ACTION to allow the user to follow the show -->
            <a class="tiny button radius" {{action follow}}>Add to watchlist</a>
        </div>
    </div>
    
		<!-- List all episodes from the show -->                
    <h2>Episodes</h2>
                                    
                                    
   <table class="table table-hover table-responsive datatable">
		<!-- Set up table columns -->     
		<thead>
        <th>Season</th>
        <th>Episode</th>
        <th>Name</th>
        <th>Synopsis</th>
        <th>Aired</th>
        <th>Watched</th>
    <thead>
    <tbody>
		<!-- Iterate through all show objects in the episodes property of the show object -->
    {{#each episode in episodes}}
       <tr>
          <td>{{ episode.season }}</td>
          <td>{{ episode.episodeNum }}</td>
          <td>{{ episode.name }}</td>
          <td>{{ episode.summary }}</td>
          <td>{{ formatDate episode.date }}</td>
          <td>{{ episode.watched }}</td>
       </tr>
   {{/each}}
   </tbody>
  </table>
          
<!-- Link back to all shows, aka the start/index page of the site -->                                                                                                                                                                                                                                                  {{#link-to-animated "index" animations="main:slideLeft"}}←All Shows{{/link-to-animated}}
                                                                                                                                                                                                                                                          </div>

```

In the example given above, we can see a bunch of different Handlebars-specific syntax, such as iterating through a list of objects, printing out properties of objects, etc.


## Worklog
