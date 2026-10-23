///|
async test "OKF acceptance scenarios" {
  @moonspec.run_or_fail(
    () => OkfWorld::OkfWorld(),
    @moonspec.RunOptions::RunOptions([
      @moonspec.FeatureSource::File("okf-acceptance/features/documents.feature"),
      @moonspec.FeatureSource::File(
        "okf-acceptance/features/relationships.feature",
      ),
      @moonspec.FeatureSource::File("okf-acceptance/features/indexes.feature"),
      @moonspec.FeatureSource::File(
        "okf-acceptance/features/validation.feature",
      ),
      @moonspec.FeatureSource::File("okf-acceptance/features/editing.feature"),
    ]),
  )
}
