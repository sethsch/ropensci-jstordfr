#' Extract meta information for books
#'
#' `jst_get_book()` extracts meta-data from JSTOR-XML files for book chapters.
#'
#' @param file_path A `.xml`-file for a book or research report.
#' 
#' @return A `tibble` containing the extracted meta-data with the following
#' columns:
#' - file_name *(chr)*: The filename of the original .xml-file. Can be used 
#'   for joining with other data for the same file.
#' - discipline *(chr)*: The discipline from the discipline names used on JSTOR.
#' - book_id *(chr)*: The book id of type "jstor", which is not a registered 
#'   DOI.
#' - book_title *(chr)*: The title of the book.
#' - book_subtitle *(chr)*: The subtitle of the book.
#' - pub_day *(int)*: Publication day, if specified.
#' - pub_month *(int)*: Publication month, if specified.
#' - pub_year *(int)*: Year of publication.
#' - isbn *(chr)*: One or more entries for the book's ISBN. If two or more, 
#'   separated by `"; "`.
#' - publisher_name *(chr)*: The name of the publisher.
#' - publisher_loc *(chr)*: The location of the publisher.
#' - n_pages *(int)*: The number of pages.
#' - language *(chr)*: The language of the book.
#'
#' A note about publication dates: always the first entry is being extracted,
#' which should correspond to the oldest date, in case there is more than one
#' date.
#' 
#' @export
#' @examples 
#' jst_get_book(jst_example("book.xml"))
jst_get_book <- function(file_path) {
  xml_file <- read_jstor(file_path)
  
  validate_book(xml_file)
  
  book <- xml_find_all(xml_file, "book-meta")
  
  out <- list(
    book_id = extract_child(book, ".//book-id"),
    file_name = jst_get_file_name(file_path),
    discipline = extract_all(
      book, ".//subj-group[@subj-group-type='discipline']"
    ),
    book_title = extract_child(book, ".//book-title"),
    book_subtitle = extract_child(book, ".//book-title-group/subtitle"),
    pub_day = extract_child(book, ".//day") %>% as.integer(),
    pub_month = extract_child(book, ".//month") %>% as.integer(),
    pub_year = extract_child(book, ".//year") %>% as.integer(),
    isbn = extract_all(book, "isbn"),
    publisher_name = extract_child(book, ".//publisher-name"),
    publisher_location = extract_child(book, ".//publisher-loc"),
    n_pages = extract_book_pages(book),
    language = extract_child(book, ".//meta-value")
  )
  
  nrow <- validate_tibble(out)
  
  new_tibble(out, nrow = nrow)
}


extract_book_pages <- function(book) {
  xml_child(book, ".//counts/page-count") %>%
    xml2::xml_attr("count") %>%
    as.integer()
}



#' Extract information on book chapters
#'
#' `jst_get_chapters()` extracts meta-data from JSTOR-XML files for book 
#' chapters.
#' 
#' Currently, `jst_get_chapters()` is quite a lot slower than most of the other 
#' functions. It is roughly 10 times slower than `jst_get_book`, depending on
#' the number of chapters to extract.
#'
#' @param file_path The path to a `.xml`-file for a book or research report.
#' @param authors Extracting the authors is an expensive operation which makes
#' the function ~3 times slower, depending on the number of chapters and
#' the number of authors. Defaults to `FALSE`. Use `authors = TRUE` to
#' import the authors too.
#' 
#' @return A `tibble` containing the extracted meta-data with the following
#' columns:
#' - book_id *(chr)*: The book id of type "jstor", which is not a registered 
#'   DOI.
#' - file_name *(chr)*: The filename of the original .xml-file. Can be used 
#'   for joining with other data for the same file.
#' - part_id *(chr)*: The id of the part.
#' - part_label *(chr)*: A label for the part, if specified.
#' - part_title *(chr)*: The title of the part.
#' - part_subtitle *(chr)*: The subtitle of the part, if specified.
#' - authors *(list)*: A list-column with information on the authors. Can be
#'   unnested with [tidyr::unnest()]. See the examples and [find_authors()].
#' - abstract *(chr)*: The abstract to the part.
#' - part_first_page *(chr)*: The page where the part begins.
#' 
#' @export
#' @examples 
#' # extract parts without authors
#' jst_get_chapters(jst_example("book.xml"))
#' 
#' # import authors too
#' parts <- jst_get_chapters(jst_example("book.xml"), authors = TRUE)
#' parts
#' 
#' tidyr::unnest(parts)
jst_get_chapters <- function(file_path, authors = FALSE) {
  xml_file <- read_jstor(file_path)

  validate_book(xml_file)

  parts <- xml_find_all(xml_file, "body") %>%
    xml_find_all("book-part/body/book-part/book-part-meta")

  # catch case with no parts
  if (purrr::is_empty(parts)) {
    parts_out <- new_tibble(list(
      part_id = NA_character_,
      part_label = NA_character_,
      part_title = NA_character_,
      part_subtitle = NA_character_,
      authors = NA_character_,
      abstract = NA_character_,
      part_first_page = NA_character_
    ), nrow = 1L)
  } else {
    parts_out <- purrr::map_df(parts, find_part, authors)
  }

  base <- list(
    book_id = extract_child(xml_file, ".//book-id") %>%
      rep(times = nrow(parts_out)),
    file_name = jst_get_file_name(file_path) %>%
      rep(times = nrow(parts_out))
  )

  dplyr::bind_cols(base, parts_out)
}



find_part <- function(part, authors = FALSE) {
  if (authors) {
    authors <- list(extract_authors(part))
  } else {
    authors <- NA_character_
  }

  out <- list(
    part_id = extract_child(part, "book-part-id"),
    part_label = extract_child(part, ".//label"),
    part_title = extract_child(part, ".//title"),
    part_subtitle = extract_child(part, ".//title-group/subtitle"),
    authors = authors,
    abstract = extract_child(part, ".//abstract"),
    part_first_page = extract_child(part, ".//fpage")
  )

  nrow <- validate_tibble(out)
  
  new_tibble(out, nrow = nrow)
}
