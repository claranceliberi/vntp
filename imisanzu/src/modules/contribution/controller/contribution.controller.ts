import { Controller, Get, HttpStatus, Param } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags, ApiParam } from '@nestjs/swagger';
import { trace, SpanStatusCode } from '@opentelemetry/api';
import { ContributionData } from '../model';
import { ContributionService } from '../service';

const tracer = trace.getTracer('imisanzu-contribution-controller');

@Controller('contributions')
@ApiTags('contribution')
export class ContributionController {

    public constructor(
        private readonly contributionService: ContributionService
    ) { }

    @Get('employee/:rssbNumber')
    @ApiOperation({ summary: 'Get employee contributions (cached from Oracle service)' })
    @ApiParam({ name: 'rssbNumber', description: 'Employee RSSB Number', example: '1023829A' })
    @ApiResponse({ status: HttpStatus.OK, isArray: true, type: ContributionData })
    public async getByEmployee(@Param('rssbNumber') rssbNumber: string): Promise<ContributionData[]> {

        return tracer.startActiveSpan('contribution.get_by_employee', async (span) => {
            span.setAttributes({
                'employee.rssb_number': rssbNumber,
                'operation.type': 'read_contributions',
                'service.component': 'imisanzu-contribution',
                'data.source': 'cached_from_oracle',
            });

            try {
                const contributions = await this.contributionService.getContributionsByRssbNumber(rssbNumber);
                
                span.setAttributes({
                    'contributions.count': contributions.length,
                    'contributions.total_amount': contributions.reduce((sum, c) => sum + c.amount, 0),
                    'operation.success': true,
                });
                
                span.setStatus({ code: SpanStatusCode.OK });
                return contributions;
            } catch (error) {
                span.recordException(error);
                span.setAttributes({
                    'operation.success': false,
                    'error.type': 'contribution_fetch_failed',
                });
                span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
                throw error;
            } finally {
                span.end();
            }
        });
    }

    @Get('cache/stats')
    @ApiOperation({ summary: 'Get cache statistics for monitoring' })
    @ApiResponse({ status: HttpStatus.OK, description: 'Cache statistics' })
    public async getCacheStats(): Promise<any> {

        return tracer.startActiveSpan('contribution.get_cache_stats', async (span) => {
            span.setAttributes({
                'operation.type': 'monitoring',
                'service.component': 'imisanzu-contribution',
                'data.type': 'cache_statistics',
            });

            try {
                const stats = await this.contributionService.getCacheStats();
                
                const totalRequests = stats.hit + stats.miss;
                const hitRate = totalRequests > 0 ? (stats.hit / totalRequests) * 100 : 0;
                
                span.setAttributes({
                    'cache.hit_rate': hitRate,
                    'cache.total_requests': totalRequests,
                    'cache.keys_count': stats.keys,
                    'operation.success': true,
                });
                
                span.setStatus({ code: SpanStatusCode.OK });
                return stats;
            } catch (error) {
                span.recordException(error);
                span.setAttributes({
                    'operation.success': false,
                    'error.type': 'cache_stats_failed',
                });
                span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
                throw error;
            } finally {
                span.end();
            }
        });
    }

}