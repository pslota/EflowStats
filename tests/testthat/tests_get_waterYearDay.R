context("get_waterYearDay")

test_that("get_waterYearDay works for normal time series.", {
        dates <- seq.Date(as.Date("2010-10-01"), as.Date("2011-09-30"),by = "day")
        out <- get_waterYearDay(dates)
        expect_equal(out, c(1:365))
})

test_that("get_waterYearDay works for leap year time series.", {
        dates <- seq.Date(as.Date("2011-10-01"), as.Date("2012-09-30"),by = "day")
        out <- get_waterYearDay(dates)
        expect_equal(out, c(1:366))
})
