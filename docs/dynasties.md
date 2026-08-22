# The problem with dynasties
A dynasty in a Sumerian setting is a sequence of rulers from a city that dominated the Sumerian area and is mentioned as such in the “Sumerian King List (SKL)". Many a times the rulers had father/son relations but not always. The reign of various rulers is famously inaccurate and was often under the influence of political propaganda, where a reign is reported to have been much longer than it probably actually was.

For example if we take the SKL, the duration of the First Dynasty of Kish was 23 rulers with a joined reign of 17.980 years. According to SKL the first ruler of that dynasty was “Jushur", who supposedly started his rule around 2900 BCE and ruled for 1200 years. Some simple math will reveal that this is probably not correct. Why? Well, likely (1) “Jushur" did not start around 2900 BCE but much sooner or (2) his reign did not last 1200 years.

At the moment the app registers birth year and death year of a figure, together with a reign in years or a start and end year of the reign. All under the assumption that this information is available either in the SKL or in another documented source.

This makes it very difficult (if not impossible) to create an accurate timeline, of the dynasty itself but also the other dynasties. The birth and death years and the reign (if at all known) become useless and require heavy guess work.

# The solution
Unless some shattering discovery is made, the actual truth will likely never be known. However, we have the SKL which mentions the dynasties, mentions the rulers by name and the sequence in which they ruled within the dynasty, all set in stone. So, what we can do is create dynasties as entities and associate rulers (figures) with them. For example “Jushur" (first ruler of the First dynasty of Kish) is associated with the lowest sequence number. I propose 10. The next ruler "Kullassina-bel” is also associated with the first Kish dynasty. His sequence number will be 20. And so on. By jumping with 10 we anticipate new figures which can be added without having to renumber the whole dynasty.

Now, the birth and death year and the duration of the reign become what they are: "couleur locale”. If they are known we store them but we do not use them to calculate things with. It is just too elaborate.