export class DataProcessingJob {
  private static isRunning = false;
  private static config = {
    durationInSeconds: 10,
    waitInSeconds: 5,
    intervalInSeconds: 1,
    intensity: 1e8,
  }

  private static processingDepth = 1;

  private static mockData = [
    { id: 1, name: 'Wireless Mouse', price: 100, category: 'electronics' },
    { id: 2, name: 'The Clean Architecture', price: 50, category: 'books' },
    { id: 3, name: 'Matrix', price: 200, category: 'movies' },
    { id: 4, name: 'Basketball', price: 75, category: 'sports' },
    { id: 5, name: 'The Clean Coder', price: 150, category: 'books' },
  ];

  static startJob(): void {
    if (this.isRunning) {
      console.log('Data processing job is already running');
      return;
    }

    this.isRunning = true;
    this.processingDepth = this.config.intensity;
    console.log('Starting data processing job...');

    // Start the job cycle
    this.runJobCycle();
  }

  private static runJobCycle() {
    if (!this.isRunning) return;

    console.log(`Starting ${this.config.durationInSeconds}-second data processing cycle...`);

    const startTime = Date.now();
    let processedBatches = 0;
    let validationResult = 0;

    const processingInterval = setInterval(() => {
      if (!this.isRunning) {
        clearInterval(processingInterval);
        return;
      }

      const elapsed = Date.now() - startTime;

      if (elapsed >= this.config.durationInSeconds * 1000) {
        clearInterval(processingInterval);
        console.log(`Data processing cycle completed. Processed ${processedBatches} batches.`);
        console.log(`Waiting ${this.config.waitInSeconds} seconds before next cycle...`);

        setTimeout(() => {
          if (this.isRunning) {
            this.runJobCycle();
          }
        }, this.config.waitInSeconds * 1000);

        return;
      }

      // Process a batch of data
      this.processDataBatch();
      processedBatches++;
    }, this.config.intervalInSeconds * 1000);

    // Data validation and quality checks
    for (let i = 0; i < this.processingDepth; i++) {
      validationResult += Math.sqrt(i) * Math.sin(i) * Math.cos(i) * Math.tan(i);
    }
  }

  private static processDataBatch(): void {
    console.log('Processing data batch...');

    // 1. Calculate total value
    const totalValue = this.calculateTotalValue();
    console.log('Total value:', totalValue);

    // 2. Group by category
    const byCategory = this.groupByCategory();
    console.log('Products by category:', byCategory);

    // 3. Find expensive items
    const expensiveItems = this.findExpensiveItems();
    console.log('Expensive items (>100):', expensiveItems);

    // 4. Generate summary
    const summary = this.generateSummary();
    console.log('Summary:', summary);
  }

  private static calculateTotalValue(): number {
    return this.mockData.reduce((sum, item) => sum + item.price, 0);
  }

  private static groupByCategory(): Record<string, any[]> {
    const grouped: Record<string, any[]> = {};

    for (const item of this.mockData) {
      if (!grouped[item.category]) {
        grouped[item.category] = [];
      }
      grouped[item.category].push(item);
    }

    return grouped;
  }

  private static findExpensiveItems(): any[] {
    return this.mockData.filter(item => item.price > 100);
  }

  private static generateSummary(): any {
    const totalValue = this.calculateTotalValue();
    const itemCount = this.mockData.length;
    const avgPrice = totalValue / itemCount;
    const categories = [...new Set(this.mockData.map(item => item.category))];

    return {
      totalItems: itemCount,
      totalValue: totalValue,
      averagePrice: avgPrice,
      categories: categories,
      timestamp: new Date().toISOString()
    };
  }

  static stopJob(): void {
    if (!this.isRunning) {
      console.log('Data processing job is not running');
      return;
    }

    console.log('Stopping data processing job...');
    this.isRunning = false;
    this.processingDepth = 1;
  }

  static isJobRunning(): boolean {
    return this.isRunning;
  }
}